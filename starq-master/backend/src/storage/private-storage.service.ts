import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export interface SavedFileInfo {
  storedFilename: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  filePath: string;
}

@Injectable()
export class PrivateStorageService {
  private readonly logger = new Logger(PrivateStorageService.name);
  private readonly storageRoot: string;

  constructor() {
    // Persistent directory configured by environment or fallback to project root data/secure_docs
    this.storageRoot = process.env.SECURE_DOCS_DIR
      ? path.resolve(process.env.SECURE_DOCS_DIR)
      : path.resolve(process.cwd(), 'data', 'secure_partner_docs');

    if (!fs.existsSync(this.storageRoot)) {
      fs.mkdirSync(this.storageRoot, { recursive: true });
      this.logger.log(`Initialized secure document storage at: ${this.storageRoot}`);
    }
  }

  async savePrivateFile(
    fileBuffer: Buffer,
    originalName: string,
    mimeType: string,
    allowedMimes: string[],
    maxBytes: number = 5 * 1024 * 1024,
  ): Promise<SavedFileInfo> {
    if (!fileBuffer || fileBuffer.length === 0) {
      throw new BadRequestException('Uploaded file is empty');
    }

    if (fileBuffer.length > maxBytes) {
      throw new BadRequestException(`File size exceeds allowed limit of ${maxBytes / (1024 * 1024)}MB`);
    }

    const cleanMime = mimeType.toLowerCase();
    if (!allowedMimes.includes(cleanMime)) {
      throw new BadRequestException(
        `Invalid file type (${mimeType}). Allowed types: ${allowedMimes.join(', ')}`,
      );
    }

    const ext = path.extname(originalName).toLowerCase() || this.extensionFromMime(cleanMime);
    const randomId = crypto.randomUUID();
    const storedFilename = `${Date.now()}_${randomId}${ext}`;
    const destination = path.join(this.storageRoot, storedFilename);

    await fs.promises.writeFile(destination, fileBuffer);

    return {
      storedFilename,
      originalName: path.basename(originalName),
      mimeType: cleanMime,
      sizeBytes: fileBuffer.length,
      filePath: destination,
    };
  }

  getPrivateFilePath(storedFilename: string): string {
    const sanitized = path.basename(storedFilename); // Guard against path traversal
    const fullPath = path.join(this.storageRoot, sanitized);
    if (!fs.existsSync(fullPath)) {
      throw new NotFoundException('Requested document was not found or has been removed');
    }
    return fullPath;
  }

  async deletePrivateFile(storedFilename: string): Promise<void> {
    try {
      const fullPath = this.getPrivateFilePath(storedFilename);
      await fs.promises.unlink(fullPath);
    } catch (_) {
      // Non-fatal if already deleted
    }
  }

  private extensionFromMime(mime: string): string {
    switch (mime) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'application/pdf':
        return '.pdf';
      default:
        return '.bin';
    }
  }
}
