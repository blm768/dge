<?xml version="1.0"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<head>
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
				<title><xsl:value-of select="/ddoc/title"/></title>
				<link rel="stylesheet" href="doc.css"/>
			</head>
			<body>
				<h1><xsl:value-of select="/ddoc/module/name"/></h1>
				<div class="content">
					<xsl:apply-templates/>
				</div>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="summary">
		<p class="summary"><xsl:apply-templates/></p>
	</xsl:template>

	<xsl:template match="desc">
		<p class="desc"><xsl:apply-templates/></p>
	</xsl:template>

	<xsl:template match="section">
		<div class="section"><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="members">
		<div class="members"><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="decl">
		<div class="decl"><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="decl_desc">
		<div class="decl_desc"><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="h">
		<div class="section_head"><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="comment">
		<span class="d_comment"><xsl:apply-templates/></span>
	</xsl:template>

	<xsl:template match="code">
		<div class="d_code"><xsl:apply-templates/></div>
	</xsl:template>
</xsl:stylesheet>
