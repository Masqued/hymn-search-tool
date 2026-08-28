#!/bin/bash

# Hymn Search Tool - Search hymnary.org and export results to CSV
# Usage: ./hymn-search.sh "search term" [output_file.csv]

set -euo pipefail

# Configuration
HYMNARY_URL="https://hymnary.org"
OUTPUT_FILE="${2:-hymn_results.csv}"
SEARCH_QUERY="${1:-}"
DEBUG="${DEBUG:-false}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
SEARCH_PAGE=$(curl -s "$SEARCH_URL")

if [[ "$DEBUG" == "true" ]]; then
    echo -e "${BLUE}Debug: First 2000 characters of search results:${NC}"
    echo "$SEARCH_PAGE" | head -c 2000
    echo -e "\n${BLUE}---${NC}\n"
fi

# Look for various hymn link patterns in the search results
# Try multiple patterns to find hymn links
HYMN_LINKS=$(echo "$SEARCH_PAGE" | grep -o 'href="[^"]*hymn[^"]*"' | sed 's/href="//; s/"$//' | sort -u)

if [[ -z "$HYMN_LINKS" ]]; then
    echo -e "${YELLOW}No hymn links found. Trying alternative search patterns...${NC}"
    
    # Try looking for /text/ links instead
    HYMN_LINKS=$(echo "$SEARCH_PAGE" | grep -o 'href="/text/[^"]*"' | sed 's/href="//; s/"$//' | sort -u)
fi

if [[ -z "$HYMN_LINKS" ]]; then
    echo -e "${RED}No hymn results found.${NC}"
    if [[ "$DEBUG" != "true" ]]; then
        echo -e "${YELLOW}Tip: Run with DEBUG=true to see the HTML structure:${NC}"
        echo "  DEBUG=true $0 \"$SEARCH_QUERY\""
    fi
    rm "$OUTPUT_FILE"
    exit 1
fi

if [[ "$DEBUG" == "true" ]]; then
    echo -e "${BLUE}Found links:${NC}"
    echo "$HYMN_LINKS"
    echo -e "\n${BLUE}---${NC}\n"
fi

# Counter for results
COUNT=0

while IFS= read -r hymn_link; do
    [[ -z "$hymn_link" ]] && continue
    
    COUNT=$((COUNT + 1))
    echo -e "${YELLOW}Processing result $COUNT: $hymn_link${NC}"
    
    # Fetch individual hymn/text page
    page_url="${HYMNARY_URL}${hymn_link}"
    hymn_page=$(curl -s "$page_url")
    
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}  URL: $page_url${NC}"
        echo -e "${BLUE}  First 1000 chars:${NC}"
        echo "$hymn_page" | head -c 1000
        echo -e "\n${BLUE}  ---${NC}"
    fi
    
    # Extract title - try multiple methods
    title=$(echo "$hymn_page" | grep -o '<title>[^<]*</title>' | sed 's/<title>//; s/<\/title>//' | sed 's/ - Hymnary\.org.*//' | xargs)
    
    # If title is empty, try h1
    if [[ -z "$title" ]]; then
        title=$(echo "$hymn_page" | grep -m1 '<h1[^>]*>' | sed 's/<[^>]*>//g' | xargs)
    fi
    
    # If title is still empty, try meta property
    if [[ -z "$title" ]]; then
        title=$(echo "$hymn_page" | grep -o 'property="og:title"[^>]*content="[^"]*' | sed 's/.*content="//; s/"$//' | xargs)
    fi
    
    # Extract author - look for various patterns
    author=""
    # Try looking for "Author:" label
    author=$(echo "$hymn_page" | grep -i 'author' | head -1 | sed 's/<[^>]*>//g' | sed 's/Author[s]*://i; s/^[[:space:]]*//; s/[[:space:]]*$//' | xargs)
    
    # Extract tune name
    tune=""
    tune=$(echo "$hymn_page" | grep -i 'tune' | head -1 | sed 's/<[^>]*>//g' | sed 's/Tune[^:]*://i; s/^[[:space:]]*//; s/[[:space:]]*$//' | xargs)
    
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
    
done <<< "$HYMN_LINKS"

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
    if [[ "$DEBUG" != "true" ]]; then
        echo -e "${YELLOW}Tip: Run with DEBUG=true to see the HTML structure:${NC}"
        echo "  DEBUG=true $0 \"$SEARCH_QUERY\""
    fi
    rm "$OUTPUT_FILE"
    exit 1
fi
