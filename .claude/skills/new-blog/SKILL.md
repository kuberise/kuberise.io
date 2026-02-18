---
name: new-blog
description: Scaffold a new blog post for the kuberise.io website
---

# New Blog Post

Create a new blog post in the website repo.

## 1. Gather information

Ask the user for:
- Title
- Brief description (1-2 sentences for SEO)
- Badge label (category, e.g., "Tutorial", "Concepts", "Guide", "Release")
- Author name (default: Mojtaba Imani)

## 2. Determine file number

Check existing blog posts in `../https.kuberise.io/content/3.blog/` to find the next sequential number.

## 3. Create the blog post file

Create `../https.kuberise.io/content/3.blog/{N}.{slug}.md` where `{slug}` is a kebab-case version of the title.

Use this frontmatter template:
```yaml
---
title: "{Title}"
description: "{Description}"
image:
  src: /img/blogs/{slug}.jpg
authors:
  - name: {Author Name}
    to: https://linkedin.com/in/{linkedin-handle}
    avatar:
      src: https://avatars.githubusercontent.com/u/{github-id}?v=4
date: {YYYY-MM-DD}
badge:
  label: {Badge}
---
```

All frontmatter fields are required by the content schema (`posts` collection in `content.config.ts`):
- `title` (string, required)
- `description` (string, required)
- `image.src` (string, required)
- `authors` (array with name, to, avatar.src - all required)
- `date` (date, required)
- `badge.label` (string, required)

## 4. Add placeholder content

Add a basic structure:
```markdown
## Introduction

{Brief intro paragraph}

## {Main sections}

{Content}

## Conclusion

{Wrap-up}
```

## 5. Remind about image

The user needs to add a blog image at `../https.kuberise.io/public/img/blogs/{slug}.jpg`. Alternatively, they can use an Unsplash URL directly in the frontmatter.

## Writing conventions

- Never use em dash - use hyphen or rephrase
- Focus on practical, actionable content
- Keep paragraphs short for web readability
