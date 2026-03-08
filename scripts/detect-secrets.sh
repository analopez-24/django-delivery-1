#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

FOUND_SECRETS=0

PATTERNS=(
    "SECRET_KEY\s*=\s*['\"][^'\"]+['\"]|Hardcoded SECRET_KEY"
    "API_KEY\s*=\s*['\"][^'\"]+['\"]|Hardcoded API_KEY"
    "api_key\s*=\s*['\"][^'\"]+['\"]|Hardcoded api_key"
    "AWS_ACCESS_KEY_ID\s*=\s*['\"][^'\"]+['\"]|Hardcoded AWS Access Key"
    "AWS_SECRET_ACCESS_KEY\s*=\s*['\"][^'\"]+['\"]|Hardcoded AWS Secret Key"
    "AKIA[0-9A-Z]{16}|AWS Access Key ID pattern"
    "password\s*=\s*['\"][^'\"]{8,}['\"]|Hardcoded password (8+ chars)"
    "token\s*=\s*['\"][A-Za-z0-9+/=]{20,}['\"]|Hardcoded token (20+ chars)"
    "PRIVATE_KEY|Private key reference"
    "BEGIN RSA PRIVATE KEY|RSA private key"
    "BEGIN EC PRIVATE KEY|EC private key"
    "BEGIN OPENSSH PRIVATE KEY|OpenSSH private key"
    "DATABASE_URL\s*=\s*['\"]postgres://|Hardcoded database URL"
    "SONAR_TOKEN\s*=\s*['\"][^'\"]+['\"]|Hardcoded Sonar token"
    "ghp_[0-9a-zA-Z]{36}|GitHub Personal Access Token"
    "sk-[0-9a-zA-Z]{48}|OpenAI API Key pattern"
    "xox[boaprs]-[0-9a-zA-Z-]+|Slack token pattern"
)

# Files/patterns to exclude from scanning
EXCLUDE_PATTERNS=(
    "detect-secrets.sh"     # This script itself
    ".pre-commit-config"    # Pre-commit config
    "test_"                 # Test files (may contain dummy secrets)
    "_test.py"              # Test files
    "VULNERABILITY_REPORT"  # Security report (documents secrets, doesn't contain them)
    "requirements"          # Requirements files
)

check_file() {
    local file="$1"

    # Skip excluded files
    for exclude in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == *"$exclude"* ]]; then
            return 0
        fi
    done

    # Skip if file doesn't exist
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    for pattern_entry in "${PATTERNS[@]}"; do
        IFS='|' read -r pattern description <<< "$pattern_entry"

        # Search for pattern, ignoring comments
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null | grep -v "^\s*#" | grep -v "# noqa" || true)

        if [[ -n "$matches" ]]; then
            echo -e "${RED}[SECRET DETECTED]${NC} $description"
            echo -e "  ${YELLOW}File:${NC} $file"
            while IFS= read -r match; do
                line_num=$(echo "$match" | cut -d: -f1)
                line_content=$(echo "$match" | cut -d: -f2- | sed 's/^[[:space:]]*//')
                echo -e "  ${YELLOW}Line $line_num:${NC} $line_content"
            done <<< "$matches"
            echo ""
            FOUND_SECRETS=1
        fi
    done
}

echo -e "${GREEN}[detect-secrets]${NC} Scanning files for hardcoded secrets..."
echo ""

# If files are passed as arguments, scan those
# Otherwise, scan all Python files
if [[ $# -gt 0 ]]; then
    for file in "$@"; do
        check_file "$file"
    done
else
    while IFS= read -r file; do
        check_file "$file"
    done < <(find . -name "*.py" -not -path "./.venv/*" -not -path "./node_modules/*")
fi

if [[ $FOUND_SECRETS -eq 1 ]]; then
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  COMMIT BLOCKED: Potential secrets detected!${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""
    echo "Options:"
    echo "  1. Remove the hardcoded secret and use environment variables instead"
    echo "  2. If this is a false positive, add '# noqa' at the end of the line"
    echo "  3. Add the file to EXCLUDE_PATTERNS in scripts/detect-secrets.sh"
    echo ""
    echo "Example fix:"
    echo "  import os"
    echo "  SECRET_KEY = os.environ.get('SECRET_KEY', 'change-me-in-production')"
    echo ""
    exit 1
else
    echo -e "${GREEN}[detect-secrets]${NC} No secrets found. Commit is safe."
    exit 0
fi
