# Civic-Link Documentation

This folder contains comprehensive documentation for the Civic-Link DPI project.

## Quick Navigation

| Document | Purpose |
|----------|---------|
| [01-Project-Overview.md](01-Project-Overview.md) | Mission, features, tech stack, roadmap |
| [02-Architecture.md](02-Architecture.md) | System design, data flows, security |
| [03-Database-Schema.md](03-Database-Schema.md) | ER diagrams, table specifications |
| [04-API-Reference.md](04-API-Reference.md) | Endpoint documentation |
| [05-Testing-Guide.md](05-Testing-Guide.md) | Test procedures and scripts |
| [06-Development-Guide.md](06-Development-Guide.md) | Setup, coding standards, workflow |
| [07-Changelog.md](07-Changelog.md) | Version history and changes |

## For New Team Members

**Start here:** [01-Project-Overview.md](01-Project-Overview.md)

Then read:
1. [02-Architecture.md](02-Architecture.md) - Understand the system
2. [06-Development-Guide.md](06-Development-Guide.md) - Set up your environment
3. [05-Testing-Guide.md](05-Testing-Guide.md) - Learn how to test

## For API Consumers

**Read:** [04-API-Reference.md](04-API-Reference.md)

Includes:
- All endpoint specifications
- Request/response examples
- Authentication details
- Error codes

## For Database Administrators

**Read:** [03-Database-Schema.md](03-Database-Schema.md)

Includes:
- ER diagrams
- Table specifications
- Indexing strategy
- PostGIS queries

## Document Formats

These are Markdown files. To convert to other formats:

### To PDF
```bash
# Using pandoc
pandoc 01-Project-Overview.md -o 01-Project-Overview.pdf

# Using VS Code extension
# Install: Markdown PDF extension
# Right-click → Markdown PDF: Export (pdf)
```

### To Word (DOCX)
```bash
pandoc 01-Project-Overview.md -o 01-Project-Overview.docx
```

### To HTML
```bash
pandoc 01-Project-Overview.md -o 01-Project-Overview.html
```

## Updating Documentation

When making code changes:
1. Update relevant .md files
2. Update [07-Changelog.md](07-Changelog.md)
3. Follow the style guide in existing docs

## Git Ignore

**Note:** This `documentation/` folder is listed in `.gitignore` and is **not** version controlled.

This is intentional:
- Docs can be regenerated/updated freely
- Keeps git history clean
- Allows project-specific documentation without conflicts

**To backup docs:**
```bash
# Copy to external storage
cp -r documentation/ /backup/location/

# Or convert to PDF and commit to separate repo
```

---

*Last Updated: April 15, 2026*
