#!/bin/bash

# Sync test reports to GitHub Pages demo
# Usage: ./scripts/sync-demo-reports.sh

set -e

echo "🔄 Syncing test reports to GitHub Pages demo..."

# Check if test_reports directory exists
if [ ! -d "test_reports" ]; then
    echo "❌ Error: test_reports directory not found"
    echo "Please run tests first to generate reports"
    exit 1
fi

# Create docs directory if it doesn't exist
mkdir -p docs

# Remove old reports and copy new ones
echo "📂 Copying reports..."
rm -rf docs/test_reports/
cp -r test_reports/ docs/

# List what was copied
echo "✅ Copied the following reports:"
ls -la docs/test_reports/

# Check if there are changes to commit
if git diff --quiet docs/test_reports/ 2>/dev/null; then
    echo "ℹ️  No changes detected in demo reports"
else
    echo "📝 Changes detected - ready to commit"
    echo ""
    echo "Next steps:"
    echo "  git add docs/test_reports/"
    echo "  git commit -m 'Update demo test reports'"
    echo "  git push origin main"
    echo ""
    echo "Or let GitHub Actions handle it automatically when you push test_reports/ changes!"
fi

echo ""
echo "🌐 Demo will be available at: https://fastapi-guard.github.io/fastapi-guard/"
echo "📊 Test reports will be at:"
echo "  - Coverage: https://fastapi-guard.github.io/fastapi-guard/test_reports/coverage_report.html"
echo "  - Security: https://fastapi-guard.github.io/fastapi-guard/test_reports/security_test_report.html"
echo "  - Performance: https://fastapi-guard.github.io/fastapi-guard/test_reports/performance_benchmark_report.html"