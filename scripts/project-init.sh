#!/bin/sh

# Set script identity for config system security
export MS_SCRIPT_ID="projinit"
VERSION="0.0.1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

usage() {
    echo "Usage: projinit <type> [name]"
    echo ""
    echo "Project types:"
    echo "  node       Node.js project with package.json"
    echo "  python     Python project with setup.py"
    echo "  go         Go module project"
    echo "  react      React application"
    echo "  next       Next.js application"
    echo "  express    Express.js API"
    echo "  fastapi    FastAPI application"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  -v, --version  Show version"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

if [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
    echo "projinit v$VERSION"
    exit 0
fi

PROJECT_TYPE="$1"
PROJECT_NAME="${2:-$(basename "$(pwd)")}"

# Load configuration values
if command -v get_config_value >/dev/null 2>&1; then
    NODE_VERSION=$(get_config_value "DEFAULT_NODE_VERSION" "18" 2>/dev/null)
    PYTHON_VERSION=$(get_config_value "DEFAULT_PYTHON_VERSION" "3.11" 2>/dev/null)
else
    NODE_VERSION="18"
    PYTHON_VERSION="3.11"
fi

case "$PROJECT_TYPE" in
    node)
        cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "keywords": [],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0"
  }
}
EOF
        
        cat > index.js << 'EOF'
console.log('Hello from Node.js!');
EOF
        
        echo "Node.js project initialized!"
        echo "Run: npm install"
        ;;
    
    python)
        cat > setup.py << EOF
from setuptools import setup, find_packages

setup(
    name="$PROJECT_NAME",
    version="0.1.0",
    packages=find_packages(),
    python_requires=">=$PYTHON_VERSION",
    install_requires=[],
)
EOF
        
        mkdir -p "$PROJECT_NAME"
        cat > "$PROJECT_NAME/__init__.py" << EOF
__version__ = "0.1.0"
EOF
        
        cat > "$PROJECT_NAME/main.py" << EOF
def main():
    print("Hello from Python!")

if __name__ == "__main__":
    main()
EOF
        
        cat > requirements.txt << EOF
# Add your requirements here
EOF
        
        echo "Python project initialized!"
        ;;
    
    go)
        MODULE_PATH="github.com/$(whoami)/$PROJECT_NAME"
        
        go mod init "$MODULE_PATH" 2>/dev/null || {
            cat > go.mod << EOF
module $MODULE_PATH

go 1.21
EOF
        }
        
        cat > main.go << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello from Go!")
}
EOF
        
        echo "Go module initialized!"
        ;;
    
    react)
        cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF
        
        mkdir -p public src
        
        cat > public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$PROJECT_NAME</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF
        
        cat > src/index.js << EOF
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
EOF
        
        cat > src/App.js << EOF
function App() {
  return (
    <div>
      <h1>Welcome to $PROJECT_NAME</h1>
    </div>
  );
}

export default App;
EOF
        
        echo "React project initialized!"
        echo "Run: npm install && npm start"
        ;;
    
    next)
        cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "eslint": "^8.0.0",
    "eslint-config-next": "14.0.0"
  }
}
EOF
        
        mkdir -p app
        
        cat > app/layout.js << EOF
export const metadata = {
  title: '$PROJECT_NAME',
  description: 'Generated by Magic Scripts',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
EOF
        
        cat > app/page.js << EOF
export default function Home() {
  return (
    <main>
      <h1>Welcome to $PROJECT_NAME</h1>
    </main>
  )
}
EOF
        
        echo "Next.js project initialized!"
        echo "Run: npm install && npm run dev"
        ;;
    
    express)
        cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Express API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
EOF
        
        cat > server.js << EOF
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Welcome to $PROJECT_NAME API' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

app.listen(PORT, () => {
  console.log(\`Server running on port \${PORT}\`);
});
EOF
        
        cat > .env.example << EOF
PORT=3000
NODE_ENV=development
EOF
        
        echo "Express API initialized!"
        echo "Run: npm install && npm run dev"
        ;;
    
    fastapi)
        cat > requirements.txt << EOF
fastapi==0.104.0
uvicorn[standard]==0.24.0
pydantic==2.4.0
python-dotenv==1.0.0
EOF
        
        cat > main.py << EOF
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="$PROJECT_NAME")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class HealthCheck(BaseModel):
    status: str = "OK"

@app.get("/")
def read_root():
    return {"message": "Welcome to $PROJECT_NAME API"}

@app.get("/health", response_model=HealthCheck)
def health_check():
    return HealthCheck()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
EOF
        
        cat > .env.example << EOF
APP_NAME=$PROJECT_NAME
DEBUG=True
EOF
        
        echo "FastAPI project initialized!"
        echo "Run: pip install -r requirements.txt && python main.py"
        ;;
    
    *)
        echo "Unknown project type: $PROJECT_TYPE"
        usage
        exit 1
        ;;
esac

echo ""
echo "Next steps:"
echo "1. Initialize git: git init"
echo "2. Create .gitignore: gigen $PROJECT_TYPE"
echo "3. Create README: readmegen -t $PROJECT_TYPE"