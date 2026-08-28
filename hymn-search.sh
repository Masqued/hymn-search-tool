#!/bin/bash

# Hymn Search Tool - Search hymnary.org and export results to CSV
# Usage: ./hymn-search.sh "search term" [output_file.csv]

set -euo pipefail

# Configuration
HYMNARY_URL="https://hymnary.org"
OUTPUT_FILE="${2:-hymn_results.csv}"
SEARCH_QUERY="${1:-}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate input
if [[ -z "$SEARCH_QUERY" ]]; then
    echo -e "${RED}Error: Search query required${NC}"
    echo "Usage: $0 \"search term\" [output_file.csv]"
    exit 1
fi

# Check for required tools
for cmd in curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}Searching hymnary.org for: \"$SEARCH_QUERY\"${NC}"

# Create CSV header
echo "Title,Author,Tune Name" > "$OUTPUT_FILE"

# URL encode the search query
encode_url() {
    local string="$1"
    echo -n "$string" | od -An -tx1 | tr ' ' % | tr -d '\n'
}

ENCODED_QUERY=$(encode_url "$SEARCH_QUERY")
SEARCH_URL="${HYMNARY_URL}/search?query=${ENCODED_QUERY}"

echo -e "${YELLOW}Fetching results from: $SEARCH_URL${NC}"

# Use curl to fetch the search results
# Parse the HTML to extract hymn information
HYMN_IDS=$(curl -s "$SEARCH_URL" | grep -o 'href="/hymn/[^"]*' | sed 's/href="\/hymn\///' | sed 's/"$//')

# Counter for results
COUNT=0

while IFS= read -r hymn_id; do
    [[ -z "$hymn_id" ]] && continue
    
    COUNT=$((COUNT + 1))
    echo -e "${YELLOW}Processing hymn $COUNT: $hymn_id${NC}"
    
    # Fetch individual hymn page
    hymn_page=$(curl -s "${HYMNARY_URL}/hymn/${hymn_id}")
    
    # Extract title (from h1 tag or title in page)
    title=$(echo "$hymn_page" | grep -m1 '<h1' | sed 's/<[^>]*>//g' | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g' | xargs)
    
    # If title is empty, try alternative extraction
    if [[ -z "$title" ]]; then
        title=$(echo "$hymn_page" | grep -m1 '<title>' | sed 's/<[^>]*>//g' | sed 's/ - Hymnary\.org.*//' | xargs)
    fi
    
    # Extract author - look for "Author" or "Words by" patterns
    author=$(echo "$hymn_page" | grep -i 'author\|words by' | head -1 | sed 's/<[^>]*>//g' | sed 's/Author[s]*://i; s/Words by://i; s/^[[:space:]]*//; s/[[:space:]]*$//' | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g' | xargs)
    
    # Extract tune name - look for "Tune" patterns
    tune=$(echo "$hymn_page" | grep -i 'tune' | head -1 | sed 's/<[^>]*>//g' | sed 's/Tune[^:]*://i; s/^[[:space:]]*//; s/[[:space:]]*$//' | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g' | xargs)
    
    # Skip if no title found
    if [[ -z "$title" ]]; then
        echo -e "${YELLOW}  Skipping - no title found${NC}"
        continue
    fi
    
    # Escape quotes for CSV
    title=$(printf '%s\n' "$title" | sed 's/"/""/g')
    author=$(printf '%s\n' "$author" | sed 's/"/""/g')
    tune=$(printf '%s\n' "$tune" | sed 's/"/""/g')
    
    # Append to CSV
    echo "\"$title\",\"$author\",\"$tune\"" >> "$OUTPUT_FILE"
    echo -e "${GREEN}  ✓ Added: $title${NC}"
    
done <<< "$HYMN_IDS"

# Check if results were found
TOTAL_LINES=$(wc -l < "$OUTPUT_FILE")
RESULT_COUNT=$((TOTAL_LINES - 1))

if [[ $RESULT_COUNT -gt 0 ]]; then
    echo -e "${GREEN}Success! Results saved to: $OUTPUT_FILE${NC}"
    echo -e "${GREEN}Found $RESULT_COUNT hymn(s)${NC}"
    # Display preview
    echo -e "${YELLOW}\nPreview:${NC}"
    head -6 "$OUTPUT_FILE" | column -t -s',' 2>/dev/null || head -6 "$OUTPUT_FILE"
else
    echo -e "${YELLOW}No hymns found for query: \"$SEARCH_QUERY\"${NC}"
    rm "$OUTPUT_FILE"
    exit 1
fi
