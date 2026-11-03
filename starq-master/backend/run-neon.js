const fs = require('fs');
const { execSync } = require('child_process');

function run() {
  const hasEnv = fs.existsSync('.env');
  if (hasEnv) {
    fs.renameSync('.env', '.env.backup');
  }
  
  try {
    if (fs.existsSync('.env.neon')) {
      fs.copyFileSync('.env.neon', '.env');
    } else {
      console.error("Error: .env.neon file not found.");
      process.exit(1);
    }
    
    const command = process.argv.slice(2).join(' ');
    console.log(`\x1b[36mRunning against Neon: ${command}\x1b[0m`);
    execSync(command, { stdio: 'inherit' });
    
  } catch (err) {
    // Command failed, but we still need to restore the env
  } finally {
    if (fs.existsSync('.env.neon') && fs.existsSync('.env')) {
      fs.rmSync('.env');
    }
    if (hasEnv && fs.existsSync('.env.backup')) {
      fs.renameSync('.env.backup', '.env');
    }
  }
}

run();
