//
//  FormElement.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * A HTML Form Element provides ready access to the form fields/controls that are associated with it. It also allows a
 * form to easily be submitted.
 */
public class FormElement: Element {
    private let _elements: Elements = Elements()

    /**
     * Create a new, standalone form element.
     *
     * @param tag        tag of this element
     * @param baseUri    the base URI
     * @param attributes initial attributes
     */
    public override init(_ tag: Tag, _ baseUri: String, _ attributes: Attributes) {
        super.init(tag, baseUri, attributes)
    }

    /**
     * Get the list of form control elements associated with this form.
     * @return form controls associated with this element.
     */
    public func elements() -> Elements {
        return _elements
    }

    /**
     * Add a form control element to this form.
     * @param element form control to add
     * @return this form element, for chaining
     */
    @discardableResult
    public func addElement(_ element: Element) -> FormElement {
        _elements.add(element)
        return self
    }

	//todo:
    /**
     * Prepare to submit this form. A Connection object is created with the request set up from the form values. You
     * can then set up other options (like user-agent, timeout, cookies), then execute it.
     * @return a connection prepared from the values of this form.
     * @throws IllegalArgumentException if the form's absolute action URL cannot be determined. Make sure you pass the
     * document's base URI when parsing.
     */
//    public func submit()throws->Connection {
//        let action: String = hasAttr("action") ? try absUrl("action") : try baseUri()
//        Validate.notEmpty(action, "Could not determine a form action URL for submit. Ensure you set a base URI when parsing.")
//        Connection.Method method = attr("method").toUpperCase().equals("POST") ?
//            Connection.Method.POST : Connection.Method.GET
//        
//        return Jsoup.connect(action)
//            .data(formData())
//            .method(method)
//    }

    //todo:
    /**
     * Get the data that this form submits. The returned list is a copy of the data, and changes to the contents of the
     * list will not be reflected in the DOM.
     * @return a list of key vals
     */
//    public List<Connection.KeyVal> formData() {
//        ArrayList<Connection.KeyVal> data = new ArrayList<Connection.KeyVal>();
//        
//        // iterate the form control elements and accumulate their values
//        for (Element el: elements) {
//            if (!el.tag().isFormSubmittable()) continue; // contents are form listable, superset of submitable
//            if (el.hasAttr("disabled")) continue; // skip disabled form inputs
//            String name = el.attr("name");
//            if (name.length() == 0) continue;
//            String type = el.attr("type");
//            
//            if ("select".equals(el.tagName())) {
//                Elements options = el.select("option[selected]");
//                boolean set = false;
//                for (Element option: options) {
//                    data.add(HttpConnection.KeyVal.create(name, option.val()));
//                    set = true;
//                }
//                if (!set) {
//                    Element option = el.select("option").first();
//                    if (option != null)
//                    data.add(HttpConnection.KeyVal.create(name, option.val()));
//                }
//            } else if ("checkbox".equalsIgnoreCase(type) || "radio".equalsIgnoreCase(type)) {
//                // only add checkbox or radio if they have the checked attribute
//                if (el.hasAttr("checked")) {
//                    final String val = el.val().length() >  0 ? el.val() : "on";
//                    data.add(HttpConnection.KeyVal.create(name, val));
//                }
//            } else {
//                data.add(HttpConnection.KeyVal.create(name, el.val()));
//            }
//        }
//        return data;
//    }

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = FormElement(_tag, baseUri!, attributes!)
		return copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = FormElement(_tag, baseUri!, attributes!)
		return copy(clone: clone, parent: parent)
	}
	public override func copy(clone: Node, parent: Node?) -> Node {
		let clone = clone as! FormElement
		for att in _elements.array() {
			clone._elements.add(att)
		}
		return super.copy(clone: clone, parent: parent)
	}
}
