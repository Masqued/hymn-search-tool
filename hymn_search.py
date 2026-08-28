#!/usr/bin/env python3
"""
Hymn Search Tool - Search hymnary.org for hymn titles and export to CSV
Uses direct HTTP requests instead of browser automation to bypass security challenges
Usage: python hymn_search.py "search term" [output_file.csv]
"""

import sys
import csv
import time
import argparse
from pathlib import Path
from typing import List, Dict, Optional
from urllib.parse import urljoin

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError as e:
    print(f"Error: Required packages not found.")
    print(f"Please install dependencies with:")
    print(f"  pip install requests beautifulsoup4")
    sys.exit(1)


class HymnSearcher:
    """Search hymnary.org and extract hymn data using HTTP requests."""
    
    BASE_URL = "https://hymnary.org"
    TIMEOUT = 30
    
    def __init__(self, debug: bool = False):
        """Initialize the searcher."""
        self.debug = debug
        self.session = requests.Session()
        # Set realistic browser headers
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
    
    def search(self, query: str) -> List[Dict[str, str]]:
        """Search hymnary.org and return list of hymn data with URLs."""
        print(f"🔍 Searching for: \"{query}\"")
        
        try:
            # Use the correct parameter: qu=
            search_url = f"{self.BASE_URL}/search?qu={query.replace(' ', '+')}"
            
            if self.debug:
                print(f"   URL: {search_url}")
            
            print("   Loading search page...")
            response = self.session.get(search_url, timeout=self.TIMEOUT)
            response.raise_for_status()
            
            content = response.text
            
            if self.debug:
                print(f"   Page loaded ({len(content)} bytes)")
            
            # Check if we're still on the challenge page
            if "bunny-shield" in content or "Establishing" in content:
                if self.debug:
                    print(f"   ⚠ Got security challenge page - retrying...")
                # Wait a moment and retry
                time.sleep(2)
                response = self.session.get(search_url, timeout=self.TIMEOUT)
                response.raise_for_status()
                content = response.text
            
            # Parse HTML
            soup = BeautifulSoup(content, 'html.parser')
            
            # Find all hymn results
            hymn_results = []
            
            # Look for h2 tags containing hymn titles
            for h2 in soup.find_all('h2'):
                # Find the link within the h2
                link = h2.find('a', href=True)
                if not link:
                    continue
                
                hymn_url = link['href']
                if not (hymn_url.startswith('/') or hymn_url.startswith('http')):
                    continue
                
                # Convert to absolute URL if relative
                if hymn_url.startswith('/'):
                    hymn_url = urljoin(self.BASE_URL, hymn_url)
                
                # Extract title from span with class "highlight"
                title_span = link.find('span', class_='highlight')
                if not title_span:
                    if self.debug:
                        print(f"   ⚠ No highlight span found in link")
                    continue
                
                title = title_span.get_text().strip()
                if not title:
                    if self.debug:
                        print(f"   ⚠ No title text found")
                    continue
                
                # Look for author in the parent or surrounding elements
                # The author should be in a span with data-fieldname="author"
                author = ""
                parent = h2.parent
                if parent:
                    author_span = parent.find('span', attrs={'data-fieldname': 'author'})
                    if author_span:
                        # Get the text and remove the "Author: " prefix
                        author_text = author_span.get_text().strip()
                        author_text = author_text.replace('Author:', '').strip()
                        author = author_text
                
                if self.debug:
                    print(f"   Found: {title}")
                    print(f"     Author: {author if author else '(not found)'}")
                    print(f"     URL: {hymn_url}")
                
                hymn_results.append({
                    'title': title,
                    'author': author,
                    'url': hymn_url
                })
            
            if self.debug:
                print(f"   Found {len(hymn_results)} hymn(s)")
                # Save HTML for debugging
                with open('debug_search.html', 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"   Saved page HTML to debug_search.html")
            
            return hymn_results
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request error: {e}")
            return []
    
    def extract_tune(self, url: str) -> str:
        """Extract tune information from a hymn detail page."""
        try:
            if self.debug:
                print(f"     Fetching tune from: {url}")
            
            response = self.session.get(url, timeout=self.TIMEOUT)
            response.raise_for_status()
            
            content = response.text
            soup = BeautifulSoup(content, 'html.parser')
            
            # Look for the link with href="#tune" that contains the tune name
            # The link text looks like: "Tune: NEW BRITAIN"
            tune = ""
            
            # Find all links and look for one with href="#tune"
            for link in soup.find_all('a', href='#tune'):
                link_text = link.get_text().strip()
                if link_text.startswith('Tune:'):
                    # Extract the tune name after "Tune: "
                    tune = link_text.replace('Tune:', '').strip()
                    break
            
            if self.debug:
                print(f"       Tune: {tune if tune else '(not found)'}")
            
            return tune
        
        except requests.exceptions.RequestException as e:
            print(f"     ⚠ Error loading page: {e}")
            return ""
        
        except Exception as e:
            if self.debug:
                print(f"     ⚠ Error processing page: {e}")
            return ""


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Search hymnary.org and export results to CSV',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python hymn_search.py "Amazing Grace"
  python hymn_search.py "Charles Wesley" results.csv
  python hymn_search.py "Gospel" results.csv --debug
  python hymn_search.py "Gospel" results.csv --no-tune
        """
    )
    
    parser.add_argument('query', help='Search query (hymn title, author, or tune name)')
    parser.add_argument('output', nargs='?', default='hymn_results.csv',
                        help='Output CSV file (default: hymn_results.csv)')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    parser.add_argument('--no-tune', action='store_true', help='Skip fetching tune information (faster)')
    
    args = parser.parse_args()
    
    if not args.query:
        parser.print_help()
        sys.exit(1)
    
    try:
        searcher = HymnSearcher(debug=args.debug)
        
        # Search for hymns
        hymn_results = searcher.search(args.query)
        
        if not hymn_results:
            print(f"❌ No hymns found for: \"{args.query}\"")
            if args.debug:
                print(f"💡 Check debug_search.html to see what was loaded")
            sys.exit(1)
        
        print(f"\n📚 Found {len(hymn_results)} result(s)")
        
        # Extract tune if not skipped
        if not args.no_tune:
            print(f"📝 Extracting tune information...")
            for i, hymn in enumerate(hymn_results, 1):
                print(f"  [{i}/{len(hymn_results)}] {hymn['title']}")
                tune = searcher.extract_tune(hymn['url'])
                hymn['tune'] = tune
        else:
            # Add empty tune field for consistency
            for hymn in hymn_results:
                hymn['tune'] = ""
        
        # Write to CSV
        output_path = Path(args.output)
        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=['title', 'author', 'tune', 'url'])
            writer.writeheader()
            writer.writerows(hymn_results)
        
        print(f"\n✅ Success!")
        print(f"✓ Found {len(hymn_results)} hymn(s)")
        print(f"✓ Saved to: {output_path.resolve()}")
        
        # Display preview
        print(f"\n📋 Preview:")
        print(f"{'Title':<50} {'Author':<30} {'Tune':<30}")
        print("-" * 110)
        for hymn in hymn_results[:5]:
            title = hymn['title'][:47] + "..." if len(hymn['title']) > 50 else hymn['title']
            author = hymn['author'][:27] + "..." if len(hymn['author']) > 30 else hymn['author']
            tune = hymn['tune'][:27] + "..." if len(hymn['tune']) > 30 else hymn['tune']
            print(f"{title:<50} {author:<30} {tune:<30}")
        
        if len(hymn_results) > 5:
            print(f"... and {len(hymn_results) - 5} more")
    
    except KeyboardInterrupt:
        print("\n⚠ Interrupted by user")
        sys.exit(0)
    
    except Exception as e:
        print(f"\n❌ Error: {e}")
        if args.debug:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
