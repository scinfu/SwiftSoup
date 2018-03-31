//
//  SwiftSoup.swift
//  Jsoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
The core public access point to the jsoup functionality.
*/
open class SwiftSoup {
    private init() {}

	/**
	Parse HTML into a Document. The parser will make a sensible, balanced document tree out of any HTML.
	
	@param html    HTML to parse
	@param baseUri The URL where the HTML was retrieved from. Used to resolve relative URLs to absolute URLs, that occur
	before the HTML declares a {@code <base href>} tag.
	@return sane HTML
	*/
	public static func parse(_ html: String, _ baseUri: String)throws->Document {
		return try Parser.parse(html, baseUri)
	}

	/**
	Parse HTML into a Document, using the provided Parser. You can provide an alternate parser, such as a simple XML
	(non-HTML) parser.
	
	@param html    HTML to parse
	@param baseUri The URL where the HTML was retrieved from. Used to resolve relative URLs to absolute URLs, that occur
	before the HTML declares a {@code <base href>} tag.
	@param parser alternate {@link Parser#xmlParser() parser} to use.
	@return sane HTML
	*/
	public static func parse(_ html: String, _ baseUri: String, _ parser: Parser)throws->Document {
		return try parser.parseInput(html, baseUri)
	}

	/**
	Parse HTML into a Document. As no base URI is specified, absolute URL detection relies on the HTML including a
	{@code <base href>} tag.
	
	@param html HTML to parse
	@return sane HTML
	
	@see #parse(String, String)
	*/
	public static func parse(_ html: String)throws->Document {
		return try Parser.parse(html, "")
	}

	//todo:
//	/**
//	* Creates a new {@link Connection} to a URL. Use to fetch and parse a HTML page.
//	* <p>
//	* Use examples:
//	* <ul>
//	*  <li><code>Document doc = Jsoup.connect("http://example.com").userAgent("Mozilla").data("name", "jsoup").get();</code></li>
//	*  <li><code>Document doc = Jsoup.connect("http://example.com").cookie("auth", "token").post();</code></li>
//	* </ul>
//	* @param url URL to connect to. The protocol must be {@code http} or {@code https}.
//	* @return the connection. You can add data, cookies, and headers; set the user-agent, referrer, method; and then execute.
//	*/
//	public static Connection connect(String url) {
//		return HttpConnection.connect(url);
//	}

	//todo:
//	/**
//	Parse the contents of a file as HTML.
//	
//	@param in          file to load HTML from
//	@param charsetName (optional) character set of file contents. Set to {@code null} to determine from {@code http-equiv} meta tag, if
//	present, or fall back to {@code UTF-8} (which is often safe to do).
//	@param baseUri     The URL where the HTML was retrieved from, to resolve relative links against.
//	@return sane HTML
//	
//	@throws IOException if the file could not be found, or read, or if the charsetName is invalid.
//	*/
//	public static Document parse(File in, String charsetName, String baseUri) throws IOException {
//	return DataUtil.load(in, charsetName, baseUri);
//	}

	//todo:
//	/**
//	Parse the contents of a file as HTML. The location of the file is used as the base URI to qualify relative URLs.
//	
//	@param in          file to load HTML from
//	@param charsetName (optional) character set of file contents. Set to {@code null} to determine from {@code http-equiv} meta tag, if
//	present, or fall back to {@code UTF-8} (which is often safe to do).
//	@return sane HTML
//	
//	@throws IOException if the file could not be found, or read, or if the charsetName is invalid.
//	@see #parse(File, String, String)
//	*/
//	public static Document parse(File in, String charsetName) throws IOException {
//	return DataUtil.load(in, charsetName, in.getAbsolutePath());
//	}

//	/**
//	Read an input stream, and parse it to a Document.
//	
//	@param in          input stream to read. Make sure to close it after parsing.
//	@param charsetName (optional) character set of file contents. Set to {@code null} to determine from {@code http-equiv} meta tag, if
//	present, or fall back to {@code UTF-8} (which is often safe to do).
//	@param baseUri     The URL where the HTML was retrieved from, to resolve relative links against.
//	@return sane HTML
//	
//	@throws IOException if the file could not be found, or read, or if the charsetName is invalid.
//	*/
//	public static Document parse(InputStream in, String charsetName, String baseUri) throws IOException {
//	return DataUtil.load(in, charsetName, baseUri);
//	}

//	/**
//	Read an input stream, and parse it to a Document. You can provide an alternate parser, such as a simple XML
//	(non-HTML) parser.
//	
//	@param in          input stream to read. Make sure to close it after parsing.
//	@param charsetName (optional) character set of file contents. Set to {@code null} to determine from {@code http-equiv} meta tag, if
//	present, or fall back to {@code UTF-8} (which is often safe to do).
//	@param baseUri     The URL where the HTML was retrieved from, to resolve relative links against.
//	@param parser alternate {@link Parser#xmlParser() parser} to use.
//	@return sane HTML
//	
//	@throws IOException if the file could not be found, or read, or if the charsetName is invalid.
//	*/
//	public static Document parse(InputStream in, String charsetName, String baseUri, Parser parser) throws IOException {
//	return DataUtil.load(in, charsetName, baseUri, parser);
//	}

	/**
	Parse a fragment of HTML, with the assumption that it forms the {@code body} of the HTML.
	
	@param bodyHtml body HTML fragment
	@param baseUri  URL to resolve relative URLs against.
	@return sane HTML document
	
	@see Document#body()
	*/
	public static func parseBodyFragment(_ bodyHtml: String, _ baseUri: String)throws->Document {
		return try Parser.parseBodyFragment(bodyHtml, baseUri)
	}

	/**
	Parse a fragment of HTML, with the assumption that it forms the {@code body} of the HTML.
	
	@param bodyHtml body HTML fragment
	@return sane HTML document
	
	@see Document#body()
	*/
	public static func parseBodyFragment(_ bodyHtml: String)throws->Document {
		return try Parser.parseBodyFragment(bodyHtml, "")
	}

//	/**
//	Fetch a URL, and parse it as HTML. Provided for compatibility; in most cases use {@link #connect(String)} instead.
//	<p>
//	The encoding character set is determined by the content-type header or http-equiv meta tag, or falls back to {@code UTF-8}.
//	
//	@param url           URL to fetch (with a GET). The protocol must be {@code http} or {@code https}.
//	@param timeoutMillis Connection and read timeout, in milliseconds. If exceeded, IOException is thrown.
//	@return The parsed HTML.
//	
//	@throws java.net.MalformedURLException if the request URL is not a HTTP or HTTPS URL, or is otherwise malformed
//	@throws HttpStatusException if the response is not OK and HTTP response errors are not ignored
//	@throws UnsupportedMimeTypeException if the response mime type is not supported and those errors are not ignored
//	@throws java.net.SocketTimeoutException if the connection times out
//	@throws IOException if a connection or read error occurs
//	
//	@see #connect(String)
//	*/
//	public static func parse(_ url: URL, _ timeoutMillis: Int)throws->Document {
//	Connection con = HttpConnection.connect(url);
//	con.timeout(timeoutMillis);
//	return con.get();
//	}

	/**
	Get safe HTML from untrusted input HTML, by parsing input HTML and filtering it through a white-list of permitted
	tags and attributes.
	
	@param bodyHtml  input untrusted HTML (body fragment)
	@param baseUri   URL to resolve relative URLs against
	@param whitelist white-list of permitted HTML elements
	@return safe HTML (body fragment)
	
	@see Cleaner#clean(Document)
	*/
	public static func clean(_ bodyHtml: String, _ baseUri: String, _ whitelist: Whitelist)throws->String? {
		let dirty: Document = try parseBodyFragment(bodyHtml, baseUri)
		let cleaner: Cleaner = Cleaner(whitelist)
		let clean: Document = try cleaner.clean(dirty)
		return try clean.body()?.html()
	}

	/**
	Get safe HTML from untrusted input HTML, by parsing input HTML and filtering it through a white-list of permitted
	tags and attributes.
	
	@param bodyHtml  input untrusted HTML (body fragment)
	@param whitelist white-list of permitted HTML elements
	@return safe HTML (body fragment)
	
	@see Cleaner#clean(Document)
	*/
	public static func clean(_ bodyHtml: String, _ whitelist: Whitelist)throws->String? {
		return try SwiftSoup.clean(bodyHtml, "", whitelist)
	}

	/**
	* Get safe HTML from untrusted input HTML, by parsing input HTML and filtering it through a white-list of
	* permitted
	* tags and attributes.
	*
	* @param bodyHtml input untrusted HTML (body fragment)
	* @param baseUri URL to resolve relative URLs against
	* @param whitelist white-list of permitted HTML elements
	* @param outputSettings document output settings; use to control pretty-printing and entity escape modes
	* @return safe HTML (body fragment)
	* @see Cleaner#clean(Document)
	*/
	public static func clean(_ bodyHtml: String, _ baseUri: String, _ whitelist: Whitelist, _ outputSettings: OutputSettings)throws->String? {
		let dirty: Document = try SwiftSoup.parseBodyFragment(bodyHtml, baseUri)
		let cleaner: Cleaner = Cleaner(whitelist)
		let clean: Document = try cleaner.clean(dirty)
		clean.outputSettings(outputSettings)
		return try clean.body()?.html()
	}

    /**
     Test if the input HTML has only tags and attributes allowed by the Whitelist. Useful for form validation. The input HTML should
     still be run through the cleaner to set up enforced attributes, and to tidy the output.
     @param bodyHtml HTML to test
     @param whitelist whitelist to test against
     @return true if no tags or attributes were removed; false otherwise
     @see #clean(String, org.jsoup.safety.Whitelist)
     */
    public static func isValid(_ bodyHtml: String, _ whitelist: Whitelist)throws->Bool {
        let dirty = try parseBodyFragment(bodyHtml, "")
        let cleaner  = Cleaner(whitelist)
        return try cleaner.isValid(dirty)
    }

}
