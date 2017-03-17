//
//  LinuxMain.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 20/12/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoupTests

XCTMain([
	testCase(CssTest.allTests),
	testCase(ElementsTest.allTests),
	testCase(QueryParserTest.allTests),
	testCase(SelectorTest.allTests),
	testCase(AttributeParseTest.allTests),
	testCase(CharacterReaderTest.allTests),
	testCase(HtmlParserTest.allTests),
	testCase(ParseSettingsTest.allTests),
	testCase(TagTest.allTests),
	testCase(TokenQueueTest.allTests),
	testCase(XmlTreeBuilderTest.allTests),
	testCase(FormElementTest.allTests),
	testCase(EntitiesTest.allTests),
	testCase(DocumentTypeTest.allTests),
	testCase(TextNodeTest.allTests),
	testCase(DocumentTest.allTests),
	testCase(AttributesTest.allTests),
	testCase(NodeTest.allTests),
	testCase(AttributeTest.allTests),
	testCase(CleanerTest.allTests)
	])
