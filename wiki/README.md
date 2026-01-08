# LifeOps Wiki Content

This directory contains the wiki pages for the LifeOps GitHub Wiki.

## Setup Instructions

### 1. Enable Wiki on GitHub

1. Go to your repository: https://github.com/stephanbirkeland/LifeOps
2. Click **Settings**
3. Scroll to **Features** section
4. Check **Wikis** to enable

### 2. Clone the Wiki Repository

GitHub wikis are separate git repositories:

```bash
# Clone the wiki repo (after enabling wiki and creating at least one page via GitHub UI)
git clone https://github.com/stephanbirkeland/LifeOps.wiki.git
cd LifeOps.wiki
```

### 3. Copy Wiki Content

```bash
# From the main LifeOps repo, copy wiki content
cp ../LifeOps/wiki/*.md .
```

### 4. Push to Wiki

```bash
git add .
git commit -m "Add initial wiki documentation"
git push
```

## Alternative: Quick Setup via GitHub UI

1. Go to https://github.com/stephanbirkeland/LifeOps/wiki
2. Click "Create the first page"
3. Copy content from `Home.md` into the editor
4. Save the page
5. Create additional pages by clicking "New Page"

## Wiki Pages

| File | Page Title | Description |
|------|------------|-------------|
| `Home.md` | Home | Wiki landing page |
| `Getting-Started.md` | Getting Started | Installation guide |
| `FAQ.md` | FAQ | Common questions |
| `Understanding-Your-Life-Score.md` | Understanding Your Life Score | Score explanation |
| `RPG-Stats-System.md` | RPG Stats System | Character stats guide |
| `_Sidebar.md` | (Sidebar) | Navigation sidebar |

## Notes

- File names with spaces use dashes (e.g., `Getting-Started.md` → "Getting Started" page)
- `_Sidebar.md` creates the navigation sidebar
- `_Footer.md` can be added for a footer on all pages
- Links use `[[Page Name]]` format
