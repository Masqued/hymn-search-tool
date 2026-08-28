# Hymn Search Tool

A bash script to search [hymnary.org](https://hymnary.org) for hymn titles and export results to a CSV file with title, author, and tune name.

## Requirements

- `bash` (version 4.0+)
- `curl` - for fetching web pages
- `jq` - for URL encoding
- `grep` - for pattern matching

### Installation

On Ubuntu/Debian:
```bash
sudo apt-get install curl jq
```

On macOS:
```bash
brew install curl jq
```

## Usage

### Basic Search
```bash
./hymn-search.sh "hymn search term"
```

This will search hymnary.org for hymns matching your query and save results to `hymn_results.csv` in the current directory.

### Custom Output File
```bash
./hymn-search.sh "hymn search term" "my_hymns.csv"
```

This saves results to `my_hymns.csv` instead of the default filename.

### Examples
```bash
# Search for hymns by title
./hymn-search.sh "Amazing Grace"

# Search for hymns by author
./hymn-search.sh "Charles Wesley"

# Search for hymns by tune name
./hymn-search.sh "Hymn Tune"

# Save to custom file
./hymn-search.sh "Gospel" "gospel_hymns.csv"
```

## Output Format

The script generates a CSV file with three columns:

```csv
Title,Author,Tune Name
"Amazing Grace","John Newton","New Britain"
"Jesus Loves Me","Anna Bartlett Warner","William Bradbury"
```

The CSV is properly formatted with quoted fields and escaped quotes for safe import into spreadsheets.

## Features

- ✅ Searches hymnary.org by hymn title, author, or tune name
- ✅ Exports results to CSV format
- ✅ Properly escapes special characters and quotes
- ✅ Color-coded output for easy reading
- ✅ Progress indicators for each hymn processed
- ✅ Error handling for missing dependencies
- ✅ Preview of results in terminal

## CSV Import

You can import the generated CSV file into:
- **Excel/LibreOffice Calc** - File → Open, select the CSV file
- **Google Sheets** - File → Import → Upload file
- **Database** - Use standard CSV import tools
- **Python/R** - Use `pandas.read_csv()` or `read.csv()`

## How It Works

1. Takes your search query and URL-encodes it
2. Fetches search results from hymnary.org
3. Extracts hymn IDs from search results
4. For each hymn found:
   - Fetches the individual hymn page
   - Parses the HTML to extract title, author, and tune name
   - Cleans up HTML entities
   - Appends to CSV file
5. Displays results summary and preview

## Notes

- The script respects hymnary.org's server by processing hymns sequentially
- Large search result sets may take several minutes to process
- Tune names may be blank for some hymns if not listed on hymnary.org
- Author information may vary depending on what's available in the hymn database

## Troubleshooting

**"curl: command not found"** - Install curl (see Requirements above)

**"jq: command not found"** - Install jq (see Requirements above)

**"No hymns found"** - Try a different search term; hymnary.org may not have results for your query

**Permission denied** - Make the script executable:
```bash
chmod +x hymn-search.sh
```

## License

MIT License - feel free to modify and distribute

## Contributing

Suggestions and improvements welcome! Feel free to open issues or submit pull requests.
