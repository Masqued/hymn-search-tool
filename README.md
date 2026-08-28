# Hymn Search Tool

A Python tool to search [hymnary.org](https://hymnary.org) for hymn titles and export results to a CSV file with title, author, and tune name.

## Features

- ✅ Searches hymnary.org by hymn title, author, or tune name
- ✅ Handles JavaScript security challenges with Playwright browser automation
- ✅ Exports results to CSV format
- ✅ Properly formatted CSV with quoted fields
- ✅ Color-coded terminal output
- ✅ Progress indicators
- ✅ Debug mode for troubleshooting
- ✅ Graceful error handling

## Requirements

- Python 3.7+
- Playwright (for browser automation to handle JavaScript)
- BeautifulSoup4 (for HTML parsing)

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/Masqued/hymn-search-tool.git
cd hymn-search-tool
```

### 2. Create a virtual environment (recommended)
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Python dependencies
```bash
pip install playwright beautifulsoup4
```

### 4. Install browser drivers
```bash
playwright install chromium
```

## Usage

### Basic Search
```bash
python hymn_search.py "hymn search term"
```

This will search hymnary.org for hymns matching your query and save results to `hymn_results.csv`.

### Custom Output File
```bash
python hymn_search.py "hymn search term" "my_hymns.csv"
```

### Debug Mode
```bash
python hymn_search.py "hymn search term" --debug
```

Shows detailed output about the search process and data extraction.

### Examples
```bash
# Search for hymns by title
python hymn_search.py "Amazing Grace"

# Search for hymns by author
python hymn_search.py "Charles Wesley" wesley_hymns.csv

# Search for hymns by tune name with debug output
python hymn_search.py "Gospel" gospel_hymns.csv --debug

# Get help
python hymn_search.py --help
```

## Output Format

The script generates a CSV file with three columns:

```csv
title,author,tune
"Amazing Grace","John Newton","New Britain"
"Jesus Loves Me","Anna Bartlett Warner","William Bradbury"
```

The CSV is properly formatted for import into spreadsheets and databases.

## CSV Import

You can import the generated CSV file into:
- **Excel/LibreOffice Calc** - File → Open, select the CSV file
- **Google Sheets** - File → Import → Upload file
- **Database** - Use standard CSV import tools
- **Python/R** - Use `pandas.read_csv()` or `read.csv()`

Example in Python:
```python
import pandas as pd
df = pd.read_csv('hymn_results.csv')
print(df.head())
```

## How It Works

1. Launches a headless Chromium browser using Playwright
2. Navigates to hymnary.org search page with your query
3. Waits for the page to fully load (including any JavaScript)
4. Extracts all hymn links from the search results
5. For each hymn found:
   - Fetches the individual hymn page
   - Parses the HTML to extract title, author, and tune name
   - Appends to CSV file
6. Displays results summary and preview

## Notes

- The first run may take a while as Playwright initializes the browser
- Subsequent searches will be faster
- Large search result sets may take several minutes to process
- Tune names may be blank for some hymns if not listed on hymnary.org
- Author information may vary depending on what's available in the hymn database
- The tool respects the website's bandwidth by processing sequentially

## Troubleshooting

**"ModuleNotFoundError: No module named 'playwright'"**
```bash
pip install playwright beautifulsoup4
playwright install chromium
```

**"No hymns found for query"**
- Try a different search term
- hymnary.org may not have results for your specific query
- Try searching by author or tune name instead

**Script runs very slowly**
- This is normal on first run due to browser initialization
- Subsequent runs will be faster
- The page needs time to load all content

**Permission denied on Linux/Mac**
```bash
chmod +x hymn_search.py
```

## Performance

- First run: ~15-30 seconds to initialize
- Subsequent searches: ~2-5 seconds per hymn
- Search with 10 results: ~30-60 seconds total

## Advanced Usage

### Using in a script
```python
from hymn_search import HymnSearcher

with HymnSearcher(debug=False) as searcher:
    hymn_urls = searcher.search("Amazing Grace")
    for url in hymn_urls:
        data = searcher.extract_hymn_data(url)
        print(data)
```

### Environment variables
- `DEBUG=true` - Enable debug output (via command line is easier)

## Bash Version (Legacy)

There is also a legacy bash version (`hymn-search.sh`) that doesn't require Python, but it cannot bypass JavaScript security challenges on the website. The Python version is recommended.

## License

MIT License - feel free to modify and distribute

## Contributing

Suggestions and improvements welcome! Feel free to open issues or submit pull requests.

## Dependencies

- **playwright** - Browser automation for handling JavaScript security
- **beautifulsoup4** - HTML parsing library
