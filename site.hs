{-# LANGUAGE OverloadedStrings #-}
-- site.hs : the recipe that builds the website.
-- You will rarely need to touch this file.

import Hakyll
import Text.Pandoc.Options (MathMethod (KaTeX), writerMathMethod)
import GHC.IO.Encoding (setLocaleEncoding, utf8)

-- The finished website is written into the folder "docs",
-- because GitHub Pages can publish a folder with that name.
config :: Configuration
config = defaultConfiguration { destinationDirectory = "docs" }

main :: IO ()
main = do
  -- Read and write all files as UTF-8 (needed on Windows for accents like é).
  setLocaleEncoding utf8
  hakyllWith config $ do

    -- Pictures and PDF files are copied as they are.
    -- "**" also includes sub-folders, e.g. files/operads/talk1.pdf
    match ("images/**" .||. "files/**") $ do
      route   idRoute
      compile copyFileCompiler

    -- The style sheet (colours, fonts, spacing).
    match "css/*" $ do
      route   idRoute
      compile compressCssCompiler

    -- Every page written in Markdown (*.md) becomes an .html page,
    -- wrapped in the common layout templates/default.html.
    -- (blog.md is the exception: it is handled just below.)
    match ("*.md" .&&. complement "blog.md") $ do
      route   $ setExtension "html"
      compile $ mathPandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

    -- Blog posts: one Markdown file per post in the folder "posts",
    -- named like 2026-11-13-my-title.md (the date comes from the name).
    match "posts/*" $ do
      route   $ setExtension "html"
      compile $ mathPandocCompiler
        >>= saveSnapshot "content"          -- remembered for the teaser
        >>= loadAndApplyTemplate "templates/post.html"    postCtx
        >>= loadAndApplyTemplate "templates/default.html" postCtx
        >>= relativizeUrls

    -- The blog page: its own text, followed by a card for every post,
    -- newest first.
    match "blog.md" $ do
      route   $ setExtension "html"
      compile $ do
        posts <- recentFirst =<< loadAll "posts/*"
        let blogCtx = listField "posts" postCtx (return posts) <> defaultContext
        mathPandocCompiler
          >>= loadAndApplyTemplate "templates/post-list.html" blogCtx
          >>= loadAndApplyTemplate "templates/default.html"   defaultContext
          >>= relativizeUrls

    -- robots.txt tells search engines where the sitemap is.
    -- Google Search Console ownership file (google....html): copied unchanged.
    match ("robots.txt" .||. "google*.html") $ do
      route   idRoute
      compile copyFileCompiler

    -- sitemap.xml: the list of all pages and posts, read by search engines.
    -- It updates itself when pages or posts are added.
    create ["sitemap.xml"] $ do
      route   idRoute
      compile $ do
        pages <- loadAll ("*.md" .||. "posts/*")
        let sitemapCtx =
              listField "pages" (constField "root" siteRoot <> defaultContext) (return pages)
        makeItem ("" :: String)
          >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

    -- The layout itself.
    match "templates/*" $ compile templateBodyCompiler

-- The public address of the website (used in the sitemap).
siteRoot :: String
siteRoot = "https://grzcz.github.io"

-- What a post knows about itself: its date (e.g. "13 Nov 2026"),
-- its teaser (the part above <!--more-->), title, address, text...
postCtx :: Context String
postCtx =
  dateField "date" "%-d %b %Y"
    <> teaserField "teaser" "content"
    <> defaultContext

-- Like the normal Markdown converter, but marks $...$ maths so that
-- KaTeX (loaded in the template) can display it nicely.
mathPandocCompiler :: Compiler (Item String)
mathPandocCompiler =
  pandocCompilerWith
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions { writerMathMethod = KaTeX "" }
