#! Minimal, self-contained LightXML navigation helpers used to read PhysiCell
#! output XML. This is the read-side subset of ModelManager's
#! `src/xml_utilities.jl`; PhysiCellOutput copies it rather than depending on
#! ModelManager. These functions are internal (not exported).

using LightXML

"""
    getChildByAttribute(parent_element::XMLElement, path_element_split::Vector{<:AbstractString})

Get the child element of `parent_element` that matches the given tag and attribute.

`path_element_split` is `[tag, attribute_name, attribute_value]`. Returns `nothing` if no
matching child exists.
"""
function getChildByAttribute(parent_element::XMLElement, path_element_split::Vector{<:AbstractString})
    path_element_name, attribute_name, attribute_value = path_element_split
    candidate_elements = get_elements_by_tagname(parent_element, path_element_name)
    for ce in candidate_elements
        if attribute(ce, attribute_name) == attribute_value
            return ce
        end
    end
    return nothing
end

"""
    getChildByChildContent(current_element::XMLElement, path_element::AbstractString)

Get the child element of `current_element` that matches the given tag and child content.

`path_element` has the form `"<tag>::<child_tag>:<child_content>"`. Returns
`(element, true)` on a match and `(current_element, false)` otherwise.
"""
function getChildByChildContent(current_element::XMLElement, path_element::AbstractString)
    tag, child_scheme = split(path_element, "::")
    tokens = split(child_scheme, ":")
    @assert length(tokens) == 2 "Invalid child scheme for $(path_element). Expected format: <tag>::<child_tag>:<child_content>"
    child_tag, child_content = tokens
    candidate_elements = get_elements_by_tagname(current_element, tag)
    for ce in candidate_elements
        child_element = find_element(ce, child_tag)
        if !isnothing(child_element) && content(child_element) == child_content
            return ce, true
        end
    end
    return current_element, false
end

"""
    retrieveElement(xml_doc::XMLDocument, xml_path::Vector{<:AbstractString}; required::Bool=true)

Retrieve the element in the XML document that matches the given path.

Each path element is a plain tag name, a `"tag:attr:value"` attribute selector, or a
`"tag::child_tag:child_content"` child-content selector. If `required` is `true`, an error
is thrown when the element is not found; otherwise `nothing` is returned.
"""
function retrieveElement(xml_doc::XMLDocument, xml_path::Vector{<:AbstractString}; required::Bool=true)
    current_element = root(xml_doc)
    for path_element in xml_path
        if contains(path_element, "::")
            current_element, success = getChildByChildContent(current_element, path_element)
            if !success
                current_element = nothing
            end
        else
            current_element = contains(path_element, ":") ?
                getChildByAttribute(current_element, split(path_element, ":"; limit=3)) :
                find_element(current_element, path_element)
        end

        if isnothing(current_element)
            required ? retrieveElementError(xml_path, path_element) : return nothing
        end
    end
    return current_element
end

"""
    retrieveElementError(xml_path::Vector{<:AbstractString}, path_element::String)

Throw an error reporting that the element defined by `xml_path` was not found, including the
path element that caused the failure.
"""
function retrieveElementError(xml_path::Vector{<:AbstractString}, path_element::String)
    error_msg = "Element not found: $(join(xml_path, " -> "))"
    error_msg *= "\n\tFailed at: $(path_element)"
    throw(ArgumentError(error_msg))
end

"""
    elementIsTerminal(e::XMLElement)

Return `true` if an XML element is terminal (has no child elements), `false` otherwise.
"""
elementIsTerminal(e::XMLElement) = isempty(child_elements(e))

"""
    getSimpleContent(xml_doc::XMLDocument, xml_path::Vector{<:AbstractString}; required::Bool=true)

Return the text content of the terminal element in the XML document that matches the given
path. See [`retrieveElement`](@ref).

Asserts that the element is terminal (has no child elements) and has non-empty text content.
When `required=false` and the path is not found, returns `nothing` (matching
[`retrieveElement`](@ref)).
"""
function getSimpleContent(xml_doc::XMLDocument, xml_path::Vector{<:AbstractString}; required::Bool=true)
    e = retrieveElement(xml_doc, xml_path; required=required)
    if isnothing(e)
        return nothing
    end
    @assert elementIsTerminal(e) "Element at path $(join(xml_path, " -> ")) has child elements and cannot have simple content extracted."
    ret_val = content(e)
    @assert !isempty(ret_val) "Element at path $(join(xml_path, " -> ")) has no text content."
    return ret_val
end
