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
    
    def search(self, query: str) -> List[str]:
        """Search hymnary.org and return list of hymn URLs."""
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
            
            # Find all hymn links
            hymn_links = []
            
            # Look for links with hymn or text in href
            for link in soup.find_all('a', href=True):
                href = link['href']
                if '/hymn/' in href or '/text/' in href:
                    # Convert to absolute URL if relative
                    if href.startswith('/'):
                        hymn_links.append(urljoin(self.BASE_URL, href))
                    elif href.startswith('http'):
                        hymn_links.append(href)
            
            # Remove duplicates and sort
            hymn_links = sorted(list(set(hymn_links)))
            
            if self.debug:
                print(f"   Found {len(hymn_links)} hymn link(s)")
                for link in hymn_links[:5]:
                    print(f"     - {link}")
                # Save HTML for debugging
                with open('debug_search.html', 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"   Saved page HTML to debug_search.html")
            
            return hymn_links
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request error: {e}")
            return []
    
    def extract_hymn_data(self, url: str) -> Optional[Dict[str, str]]:
        """Extract hymn data from a hymn page."""
        try:
            if self.debug:
                print(f"   Fetching: {url}")
            
            response = self.session.get(url, timeout=self.TIMEOUT)
            response.raise_for_status()
            
            content = response.text
            soup = BeautifulSoup(content, 'html.parser')
            
            # Extract title
            title = None
            title_elem = soup.find('title')
            if title_elem:
                title = title_elem.get_text().replace(' - Hymnary.org', '').strip()
            
            if not title:
                h1 = soup.find('h1')
                if h1:
                    title = h1.get_text().strip()
            
            if not title:
                og_title = soup.find('meta', property='og:title')
                if og_title and og_title.get('content'):
                    title = og_title['content'].strip()
            
            if not title:
                if self.debug:
                    print(f"     ⚠ No title found")
                return None
            
            # Extract author
            author = ""
            for elem in soup.find_all(string=True):
                if 'Author' in elem or 'Words by' in elem:
                    parent = elem.parent
                    # Get text from parent and siblings
                    text = parent.get_text().strip()
                    # Clean up the text
                    text = text.replace('Author:', '').replace('Words by:', '').strip()
                    if text and len(text) < 200:  # Reasonable length
                        author = text
                        break
            
            # Extract tune
            tune = ""
            for elem in soup.find_all(string=True):
                if 'Tune' in elem:
                    parent = elem.parent
                    text = parent.get_text().strip()
                    text = text.replace('Tune:', '').replace('Tune Name:', '').strip()
                    if text and len(text) < 100:  # Reasonable length
                        tune = text
                        break
            
            if self.debug:
                print(f"     ✓ Title: {title}")
                print(f"       Author: {author if author else '(not found)'}")
                print(f"       Tune: {tune if tune else '(not found)'}")
            
            return {
                'title': title,
                'author': author,
                'tune': tune,
                'url': url
            }
        
        except requests.exceptions.RequestException as e:
            print(f"     ⚠ Error loading page: {e}")
            return None
        
        except Exception as e:
            if self.debug:
                print(f"     ⚠ Error processing page: {e}")
            return None


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
        """
    )
    
    parser.add_argument('query', help='Search query (hymn title, author, or tune name)')
    parser.add_argument('output', nargs='?', default='hymn_results.csv',
                        help='Output CSV file (default: hymn_results.csv)')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    
    args = parser.parse_args()
    
    if not args.query:
        parser.print_help()
        sys.exit(1)
    
    try:
        searcher = HymnSearcher(debug=args.debug)
        
        # Search for hymns
        hymn_urls = searcher.search(args.query)
        
        if not hymn_urls:
            print(f"❌ No hymns found for: \"{args.query}\"")
            if args.debug:
                print(f"💡 Check debug_search.html to see what was loaded")
            sys.exit(1)
        
        print(f"\n📚 Found {len(hymn_urls)} result(s)")
        print(f"📝 Extracting hymn data...")
        
        # Extract data from each hymn
        hymns = []
        for i, url in enumerate(hymn_urls, 1):
            print(f"\n  [{i}/{len(hymn_urls)}] {url.split('/')[-1]}")
            data = searcher.extract_hymn_data(url)
            if data:
                hymns.append(data)
        
        if not hymns:
            print(f"\n❌ No hymn data could be extracted")
            sys.exit(1)
        
        # Write to CSV
        output_path = Path(args.output)
        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=['title', 'author', 'tune', 'url'])
            writer.writeheader()
            writer.writerows(hymns)
        
        print(f"\n✅ Success!")
        print(f"✓ Found {len(hymns)} hymn(s)")
        print(f"✓ Saved to: {output_path.resolve()}")
        
        # Display preview
        print(f"\n📋 Preview:")
        print(f"{'Title':<50} {'Author':<30} {'Tune':<30}")
        print("-" * 110)
        for hymn in hymns[:5]:
            title = hymn['title'][:47] + "..." if len(hymn['title']) > 50 else hymn['title']
            author = hymn['author'][:27] + "..." if len(hymn['author']) > 30 else hymn['author']
            tune = hymn['tune'][:27] + "..." if len(hymn['tune']) > 30 else hymn['tune']
            print(f"{title:<50} {author:<30} {tune:<30}")
        
        if len(hymns) > 5:
            print(f"... and {len(hymns) - 5} more")
    
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
