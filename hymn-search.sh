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
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}Searching hymnary.org for: \"$SEARCH_QUERY\"${NC}"

# Create CSV header
echo "Title,Author,Tune Name" > "$OUTPUT_FILE"

# Search hymnary.org using their search endpoint
# The script fetches the search results page and parses hymn data
SEARCH_URL="${HYMNARY_URL}/search?query=$(printf '%s\n' "$SEARCH_QUERY" | jq -sRr @uri)"

echo -e "${YELLOW}Fetching results from: $SEARCH_URL${NC}"

# Use curl to fetch the search results
# Parse the HTML to extract hymn information
curl -s "$SEARCH_URL" | grep -oP '(?<=<a href="/hymn/)[^"]*' | while read -r hymn_id; do
    echo -e "${YELLOW}Processing hymn: $hymn_id${NC}"
    
    # Fetch individual hymn page
    hymn_page=$(curl -s "${HYMNARY_URL}/hymn/${hymn_id}")
    
    # Extract title (from the h1 tag or meta title)
    title=$(echo "$hymn_page" | grep -oP '(?<=<h1[^>]*>)[^<]+' | head -1 | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g')
    
    # Extract author (from data-author or author meta tag)
    author=$(echo "$hymn_page" | grep -oP 'Author[s]?:?\s*</?\w+[^>]*>\s*\K[^<]+' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g')
    
    # Extract tune name (from Tune: field or music data)
    tune=$(echo "$hymn_page" | grep -oP 'Tune[^:]*:\s*</?\w+[^>]*>\s*\K[^<]+' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&lt;/</g; s/&gt;/>/g')
    
    # Skip if no title found
    if [[ -z "$title" ]]; then
        continue
    fi
    
    # Escape quotes for CSV
    title=$(printf '%s\n' "$title" | sed 's/"/""/g')
    author=$(printf '%s\n' "$author" | sed 's/"/""/g')
    tune=$(printf '%s\n' "$tune" | sed 's/"/""/g')
    
    # Append to CSV
    echo "\"$title\",\"$author\",\"$tune\"" >> "$OUTPUT_FILE"
    
done

# Check if results were found
if [[ $(wc -l < "$OUTPUT_FILE") -gt 1 ]]; then
    echo -e "${GREEN}Success! Results saved to: $OUTPUT_FILE${NC}"
    echo -e "${GREEN}Found $(( $(wc -l < "$OUTPUT_FILE") - 1 )) hymn(s)${NC}"
    # Display preview
    echo -e "${YELLOW}\nPreview:${NC}"
    head -5 "$OUTPUT_FILE" | column -t -s',' | sed 's/^/  /'
else
    echo -e "${YELLOW}No hymns found for query: \"$SEARCH_QUERY\"${NC}"
    exit 1
fi
