<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://oxygenxml.com/ns/doc/xsl"
  xmlns:util="http://example/com/util/namespace"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  version="2.0"
  xpath-default-namespace="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="xsl xs tei xd"
  xmlns="http://www.w3.org/1999/xhtml">

  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> Sep 12, 2016</xd:p>
      <xd:p><xd:b>Author:</xd:b> Johannes Baiter</xd:p>
      <xd:p>
        This stylesheet is designed to take input in the form of TEI XML with
        coordinates at the character level and produce basic HOCR XHTML with
        coordinates at the line-level, suitable for generating training files
        for ocropus/clstm.
      </xd:p>
      <xd:p>
        You can provide a where the images for the pages are located
        with with `imageDirectory` variable. The image files are expected
        to follow the pattern `00000001.$imageFormat`, i.e. the page number
        padded to 8 digits. To specify an image format other than TIF,
        set the `imageExtension` variable to the desired extension.
      </xd:p>
    </xd:desc>
  </xd:doc>

  <xsl:output method="html" encoding="UTF-8" indent="yes"
              omit-xml-declaration="yes" />

  <xsl:param name="docTitle" select="'OCRed document'"/>
  <xsl:param name="imageDirectory" as="xs:string" select="'./img'"/>
  <xsl:param name="imageExtension" as="xs:string" select="'tif'" />

  <xsl:template match="text()|@*" />

  <!-- TODO:
       - Generate ocrx_word or ocr_cinfo elements for the words
         (split on whitespace)
       - Improve performance
    -->

  <xsl:function name="util:get-bbox">
    <!-- Generate bounding box information from the passed character nodes -->
    <xsl:param name="charNodes" />

    <xsl:variable name="bbox">
      <xsl:text>bbox </xsl:text>
      <xsl:for-each select="$charNodes[@ulx != '-1' and @ulx != '']">
        <xsl:sort select="./@ulx" data-type="number" order="ascending" />
        <xsl:if test="position() = 1">
          <xsl:value-of select="@ulx" />
        </xsl:if>
        <xsl:text> </xsl:text>
      </xsl:for-each>
      <xsl:for-each select="$charNodes[@uly != '-1' and @uly != '']">
        <xsl:sort select="./@uly" data-type="number" order="ascending" />
        <xsl:if test="position() = 1">
          <xsl:value-of select="@uly" />
        </xsl:if>
        <xsl:text> </xsl:text>
      </xsl:for-each>
      <xsl:for-each select="$charNodes[@lrx != '-1' and @lrx != '']">
        <xsl:sort select="./@lrx" data-type="number" order="descending" />
        <xsl:if test="position() = 1">
          <xsl:value-of select="@lrx" />
        </xsl:if>
        <xsl:text> </xsl:text>
      </xsl:for-each>
      <xsl:for-each select="$charNodes[@lry != '-1' and @lry != '']">
        <xsl:sort select="./@lry" data-type="number" order="descending" />
        <xsl:if test="position() = 1">
          <xsl:value-of select="@lry" />
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:value-of select="replace($bbox, '\s+', ' ')" />
  </xsl:function>

  <xsl:template match="/">
    <html>
      <head>
        <title>
          <xsl:value-of select="$docTitle" />
        </title>
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
      </head>
      <xsl:apply-templates select=".//tei:text"/>
    </html>
  </xsl:template>

  <xsl:template match="tei:text">
    <body>
        <xsl:apply-templates select=".//tei:pb" />
    </body>
  </xsl:template>

  <xsl:template match="tei:pb">
      <xsl:variable name="pageNo" select="substring(./@facs, 3)" />
      <xsl:variable
        name="imageString"
        select="concat('image ', $imageDirectory, '0000', $pageNo, '.', $imageExtension)" />
      <xsl:variable
        name="pageNoString"
        select="concat('ppageno ', replace($pageNo, '^0+', ''))" />

      <div class="ocr_page" id="{concat('page_', substring(./@facs, 3))}"
           title="{$imageString}; {$pageNoString}">
        <xsl:variable name="current_page" select="./@facs" />
      <xsl:apply-templates
          select="following::tei:lb[preceding::tei:pb[1]/@facs = $current_page]" />
    </div>
  </xsl:template>

  <xsl:template match="tei:lb">
    <!-- FIXME: For some reason I haven't quite worked out how to do this
                without calling generate-id for identity comparison... -->
    <xsl:variable name="current_id" select="generate-id()" />
    <xsl:variable
      name="charNodes"
      select="preceding::tei:c[
                generate-id(following::tei:lb[1]) = $current_id]" />
    <xsl:variable name="bbox" select="util:get-bbox($charNodes)" />
    <xsl:element name="span">
      <xsl:attribute name="class">ocr_line</xsl:attribute>
      <xsl:if test="$bbox != 'bbox '">
        <xsl:attribute name="title" select="$bbox" />
      </xsl:if>
      <xsl:apply-templates select="$charNodes" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="tei:lg[@type='poem']">
    <div class="ocr_carea">
      <xsl:apply-templates />
    </div>
  </xsl:template>

  <xsl:template match="tei:lg[@n]">
    <p class="ocr_par">
      <xsl:apply-templates />
    </p>
  </xsl:template>

  <xsl:template match="tei:l">
    <xsl:variable name="charNodes" select=".//tei:c" />
    <xsl:variable name="bbox" select="util:get-bbox($charNodes)" />
    <xsl:element name="span">
      <xsl:attribute name="class">ocr_line hardbreak=1</xsl:attribute>
      <xsl:if test="$bbox != 'bbox '">
        <xsl:attribute name="title" select="$bbox" />
      </xsl:if>
      <xsl:apply-templates select="$charNodes" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="tei:p">
    <p class="ocr_par">
      <xsl:apply-templates />
    </p>
  </xsl:template>

  <xsl:template match="tei:fw[@type='page number']">
    <header class="ocr_pageno">
      <xsl:value-of select="text()" />
    </header>
  </xsl:template>

  <xsl:template match="tei:c">
    <xsl:value-of select="text()" />
  </xsl:template>

   <xsl:template match="*">
    <xsl:message terminate="no">
      WARNING: Unmatched element: <xsl:value-of select="name()"/>
    </xsl:message>
    <xsl:apply-templates/>
  </xsl:template>
</xsl:stylesheet>
