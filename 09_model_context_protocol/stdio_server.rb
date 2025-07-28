require "bundler/setup"
require "mcp"
require "mcp/server/transports/stdio_transport"
require "uri"

DOCS = {
  "deposition.md" => "This deposition covers the testimony of Angela Smith, P.E.",
  "report.pdf" => "The report details the state of a 20m condenser tower.",
  "financials.docx" => "These financials outline the project's budget and expenditures.",
  "outlook.pdf" => "This document presents the projected future performance of the system.",
  "plan.md" => "The plan outlines the steps for the project's implementation.",
  "spec.txt" => "These specifications define the technical requirements for the equipment."
}

class ReadDocContents < MCP::Tool
  description "Read the contents of a document and return it as a string."
  input_schema(
    properties: {
      doc_id: {type: "string"}
    },
    required: ["doc_id"]
  )

  def self.call(doc_id:, server_context:)
    unless DOCS[doc_id]
      raise "Doc with id #{doc_id} not found"
    end

    MCP::Tool::Response.new([{
      type: "text",
      text: DOCS[doc_id]
    }])
  end
end

class Format < MCP::Prompt
  prompt_name "format"  # Optional - defaults to underscored class name
  description "Rewrites the contents of the document in Markdown format."
  arguments [
    MCP::Prompt::Argument.new(
      name: "doc_id",
      description: "Document ID",
      required: true
    )
  ]

  def self.template(args, server_context:)
    prompt = <<~EOS
      Your goal is to reformat a document to be written with markdown syntax.

      The id of the document you need to reformat is:
      <document_id>
      #{args[:doc_id]}
      </document_id>

      Add in headers, bullet points, tables, etc as necessary.
      Feel free to add in extra text, but don't change the meaning of the report.
      Use the 'edit_document' tool to edit the document.
      After the document has been edited, respond with the final version of the doc.
      Don't explain your changes.
    EOS

    MCP::Prompt::Result.new(
      description: "Response description",
      messages: [
        MCP::Prompt::Message.new(
          role: "user",
          content: MCP::Content::Text.new(prompt)
        )
      ]
    )
  end
end

MY_RESOURCE = MCP::Resource.new(
  uri: "docs://documents",
  name: "list_docs",
  description: "Documents resource description",
  mime_type: "application/json"
)

MY_RESOURCE_TEMPLATE = MCP::ResourceTemplate.new(
  uri_template: "docs://documents/{id}",
  name: "Test resource template",
  description: "Test resource",
  mime_type: "text/plain"
)

server = MCP::Server.new(
  name: "example_server",
  tools: [ReadDocContents],
  prompts: [Format],
  resources: [MY_RESOURCE],
  resource_templates: [MY_RESOURCE_TEMPLATE]
)

server.resources_read_handler do |params|
  parsed_uri = URI(params[:uri]).

    text = nil
  if parsed_uri.path.empty?
    text = DOCS.keys
  else
    doc_id = parsed_uri.path[1..]
    unless DOCS[doc_id]
      raise "Resource with id #{doc_id} not found"
    end
    text = DOCS[doc_id]
  end

  [{
    uri: params[:uri],
    mimeType: "text/plain",
    text: text
  }]
end

# Create and start the transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
