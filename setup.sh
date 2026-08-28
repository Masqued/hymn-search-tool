#!/bin/bash
# Setup script for Hymn Search Tool

set -e

echo "🎵 Hymn Search Tool - Setup"
echo "=============================="
echo ""

# Check Python version
echo "✓ Checking Python version..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3.7 or later from https://www.python.org"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "  Found Python $PYTHON_VERSION"
echo ""

# Create virtual environment
echo "✓ Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  Created venv/"
else
    echo "  venv/ already exists"
fi
echo ""

# Activate virtual environment
echo "✓ Activating virtual environment..."
source venv/bin/activate
echo "  Virtual environment activated"
echo ""

# Upgrade pip
echo "✓ Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1
echo "  pip upgraded"
echo ""

# Install dependencies
echo "✓ Installing Python dependencies..."
pip install -r requirements.txt > /dev/null 2>&1
echo "  Dependencies installed:"
echo "    - playwright"
echo "    - beautifulsoup4"
echo ""

# Install browser
echo "✓ Installing Playwright browser..."
playwright install chromium > /dev/null 2>&1
echo "  Chromium browser installed"
echo ""

# Make script executable
echo "✓ Making scripts executable..."
chmod +x hymn_search.py
echo "  hymn_search.py is executable"
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Activate the virtual environment:"
echo "     source venv/bin/activate"
echo ""
echo "  2. Run a search:"
echo "     python hymn_search.py \"Amazing Grace\""
echo ""
echo "For more examples and options, see README.md"
