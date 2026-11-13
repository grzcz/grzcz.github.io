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
    match "*.md" $ do
      route   $ setExtension "html"
      compile $ mathPandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

    -- The layout itself.
    match "templates/*" $ compile templateBodyCompiler

-- Like the normal Markdown converter, but marks $...$ maths so that
-- KaTeX (loaded in the template) can display it nicely.
mathPandocCompiler :: Compiler (Item String)
mathPandocCompiler =
  pandocCompilerWith
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions { writerMathMethod = KaTeX "" }
