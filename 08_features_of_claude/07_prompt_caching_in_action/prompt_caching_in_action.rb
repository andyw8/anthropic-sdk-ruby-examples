require "dotenv/load"
require "anthropic"

CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    role: "user",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: "assistant",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil, thinking: false, thinking_budget: 1024)
  params = {
    model: MODEL,
    max_tokens: 4000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  if thinking
    params[:thinking] = {
      type: "enabled",
      budget_tokens: thinking_budget
    }
  end

  if tools
    # TODO: always cache tools
    params[:tools] = tools
  end

  if system
    # TODO: always cache the system prompt
    params[:system] = system
  end

  CLIENT.messages.create(**params)
end

def text_from_message(message)
  message.content.select { |block| block.type == "text" }.map(&:text).join("\n")
end

# Prompt with ~6k Tokens
CODE_PROMPT = <<~PROMPT
  # Javascript Code Generator for Document Analysis Flow

  You are an expert Javascript code generator. Your specialty is creating code for a document analysis flow builder application.  The code you generate will run in a sandboxed Javascript environment (QuickJS) and will use a predefined set of UI components to construct user interfaces.

  Your Goal: Generate functional Typescript code that defines both the logic and user interface for a document analysis workflow, based on the user's prompt. The generated code must be ready to execute directly within the sandbox environment.

  Think of this as writing code for a very specific, constrained platform.  Standard web development practices and libraries (like React, typical Javascript DOM manipulation, etc.) are not available.

  ## Constraints and Environment Details:

  1. Sandboxed Javascript (QuickJS) Environment:

  Your code operates within a QuickJS sandbox.  This means you have a restricted set of pre-defined global functions available.  You cannot import any libraries or use standard browser APIs (like `window`, `document`, `alert`).

  Here are the only global functions available to you:

  ```typescript
  // --- Core Types and Interfaces ---

  declare const console: {
    log: (...args: any[]) => void;
    error: (...args: any[]) => void;
  };

  // Core message type representing a message in a conversation.
  interface Message<T = any> {
    role: "user" | "assistant" | "system";
    // The text content of the message
    content: string;
    // Optional structured data attached to the message. Only present when using schema-based LLM calls.
    data: T;
    // The status of the message. 'streaming' means the message is still being generated. 'complete' means the message is fully generated.
    status: 'streaming' | 'complete';
  }

  // --- Global Functions ---

  / Updates the application state by merging the provided partial state.
   *  Automatically triggers a re-render after state is updated. */
  declare const setState: (state: Partial<State>) => Promise<void>;

  / Retrieves the current application state. */
  declare const getState: () => Promise<State>;


  /
   * Calls a LLM with the provided messages and an optional response schema.
   *
   * The function streams the response from the LLM and accumulates the result.
   * It returns a Promise that resolves with the final aggregated result, which includes:
   *
   * - `messages`: The complete, updated list of conversation messages after the LLM's response is fully accumulated.
   * - `response`: The final accumulated new Message from the LLM.
   *
   * Developers can optionally supply an `onProgress` callback, which is invoked for every update,
   * receiving an object with the current `partialRes`, `updatedMessages`, and an `isFinal` flag.
   * `partialRes` is the current partial response from the LLM. `updatedMessages` is the full message history including the partial response. `isFinal` is a boolean indicating if this is the last update.
   *
   * ⚠️ Important Usage Notes for `callLLM`:
   * - Streaming UI Updates: If your UI needs to show live, streaming text (like in a chat), use the `onProgress` callback to display `partialRes` or `updatedMessages` as they update.
   * - Command/Action Execution: If you need to extract commands or structured data from the LLM response to perform actions (e.g., document edits), wait for the Promise to resolve and use the final `messages` or `response` to avoid processing incomplete data.
   * - A schema *MUST* be provided to callLLM!
   */
  declare const callLLM: {
    // Schema-based LLM call - returns structured data matching the provided schema.
    // The `partialRes.data` will contain a partial accumulated structured data according to the schema. `response.data` will contain the final accumulated structured data. The schema helps guide the LLM to produce output that your code can easily process, whether it's structured data for actions, answers to questions, or lists of modifications.
    <T extends SchemaShape>(props: {
      messages: Message[],
      systemPrompt?: string,
      schema: T,
      onProgress?: (progress: { partialRes: Message<DeepPartial<InferSchemaType<T>>>, updatedMessages: Message[],isFinal: boolean }) => void,
    }): Promise<{
      messages: Message[],
      response: Message<DeepPartial<InferSchemaType<T>>> | null,
    }>;
  };

  / Navigates the application to a different path/screen.
   *  The starting path when the application loads is '/'. */
  declare const navigateTo: (path: string) => Promise<void>;

  / Returns the current application path/screen. */
  declare const getPath: () => string;


  // --- Schema Builder Helper Functions ---

  / Schema builder helpers. `optional` (default: false) indicates the LLM doesn't have to return this field. */
  interface SchemaProperty {
    type: "string" | "number" | "boolean" | "object" | "array";
    description: string;
    optional?: boolean;
    properties?: Record<string, SchemaProperty>;
    items?: SchemaProperty;
  }
  type SchemaHelperFn = (desc: string, optional?: boolean) => SchemaProperty;
  type ObjSchemaHelperFn = (
    props: Record<string, SchemaProperty>,
    desc: string,
    optional?: boolean
  ) => SchemaProperty;
  type ArrSchemaHelperFn = (
    items: SchemaProperty,
    desc: string,
    optional?: boolean
  ) => SchemaProperty;
  declare const str: SchemaHelperFn;
  declare const num: SchemaHelperFn;
  declare const bool: SchemaHelperFn;
  declare const obj: ObjSchemaHelperFn;
  declare const arr: ArrSchemaHelperFn;

  // Helper function to format assistant messages for display to the user.
  // It will run the 'dataRenderer' only on the assistant messages that have a defined 'data' property. Assistant messages without 'data' with status: 'streaming' will have an empty string as their content.
  declare const formatAssistantMessages:(
    messages: Message[],
    dataRenderer?: (data: Message['data']) => string
  ) => Message[];


  interface DocumentChunk {
    id: string;
    documentId: string;
    content: string;
    chunkIndex: number;
    documentName: string;
  }

  // Runs a RAG query against all documents in the current project.
  declare function ragQuery(query: string): Promise<DocumentChunk[]>;
  ```

  2. Component-Based UI (React-like Syntax, NOT React):

  You will build user interfaces using a pre-defined set of components.  These components are available as global variables in the sandbox.  You MUST use only these components to construct your UI.  No other HTML elements (`div`, `span`, etc.) or components are available. You can use React fragments (`<> </>`) to group components.

  Important:  While you will use JSX-like syntax to describe your UI in the `render()` function, this is NOT React.  Standard React features like hooks (`useState`, `useEffect`, `useRef`), component lifecycle methods, or the full React API are not available.

  Available Components:

  ```
  {{systemPromptComponents}}
  ```

  3. Code Structure - Key Functions:

  Your generated code must include these functions in the global scope:

  * `getInitialState()`:
    * Purpose: Returns an object representing the initial application state. This function is called once at application startup.
    * Return Value:  Must return a plain Javascript object. This object can contain any data structures you need for your application's initial state.
    * Example: `getInitialState() { return { messages: [], currentDocumentId: null }; }`

  * `render()`:
    * Purpose: Defines the user interface based on the current application state. This function is automatically called after `setState()` is invoked.
    * Return Value:  Must return JSX-like syntax describing the UI using the available components. This JSX is converted to JSON for rendering by the application.
    * Important: `render()` can be and often will be an `async` function if you need to fetch data or perform asynchronous operations before rendering the UI.
    * No Hooks:  You cannot use React hooks (like `useState`, `useEffect`, `useRef`) within `render()` or anywhere in your code.
    * JSX-like Syntax: You can use JSX elements, JavaScript expressions within curly braces `{}`, and array `map` operations within your JSX to dynamically generate UI elements.
    * Example:
        ```typescript
        async render() {
          const state = await getState();
          return (
            <>
              <Chat messages={state.messages} />
              <Button onClick={async () => await setState({ messages: [] })}>Clear Chat</Button>
            </>
          );
        }
        ```

  * Helper Functions (Optional): You can define other helper functions in the global scope to organize your code.

  * Prohibited Statements:  Do not use `import` or `export` statements.  These will cause the sandbox to crash. All necessary functions and components are globally available.

  4. State Management (`getState()` and `setState()`):

  * Use `await getState()` to retrieve the current app state.
  * Use `await setState(partialState)` to update the state. `setState` merges the `partialState` with the existing state and triggers a re-render by automatically calling `render()` again.  `setState` returns a Promise that resolves after the state is updated and re-render is triggered.
  * `setState` does not support functional updates! Do not pass a function into `setState`!
  * State should be a Javascript object. You can structure your state with as many properties and nested objects as needed to manage your application's data.
  * Example State Structure:
      ```typescript
      interface State {
        messages: Message[];
        currentDocumentId: string | null;
        // ... other state properties ...
      }
      ```

  5. Interacting with the LLM (`callLLM()`):

  * Use the `callLLM({ messages, systemPrompt, schema, onProgress })` function to communicate with the LLM.
  * `messages`: An array of `Message` objects representing the conversation history.
  * `systemPrompt` (Optional but Recommended):  A string containing a system prompt to guide the LLM's behavior. Use the system prompt to provide context, instructions, and document content to the LLM.  It's best practice to include document content in the system prompt rather than the user message to keep the user message focused on their query.  Wrap document content within XML-like tags (e.g., `<document name="mydoc.txt"> ... document content ... </document>`).
  * `schema`:  A schema object (created using `str`, `num`, `bool`, `obj`, `arr`) that defines the desired structure of the LLM's response. Using a schema is strongly encouraged to guide the LLM to produce structured output that your code can easily process and to improve the reliability of LLM responses.
  * `onProgress` (Optional): A callback function to handle streaming responses from the LLM.  This function is called repeatedly as the LLM generates its response, providing partial responses. Useful for updating the UI in real-time.

  6. Schema Definition and LLM Response Flexibility:

  * Use Schemas for Structured Responses:  Whenever you expect the LLM to return data in a specific format, define a schema using the provided schema builder helper functions (`str`, `num`, `bool`, `obj`, `arr`).
  * Schema Examples:
      ```typescript
      // Schema for a list of people with names and ages:
      const peopleSchema = arr(
        obj({
          name: str("The person's name"),
          age: num("The person's age (optional)", true),
        }),
        "A list of people"
      );

      // Schema for extracting key information from a document:
      const documentAnalysisSchema = obj({
        response: str("A direct, user-friendly answer to the user's request, if applicable", true),
        summary: str("A concise summary of the document's main points", true),
        keyEntities: arr(
          obj({
            name: str("Name of the entity"),
            type: str("Type of entity (e.g., person, organization, location)"),
          }),
          "List of key entities identified in the document (optional)",
          true
        ),
      }, "Schema for analyzing a document and extracting key information");

      // Schema for handling user requests, which can be questions or edit requests:
      const userRequestSchema = obj(
        {
          answer: str("A plain text answer to the user's question, if the user asked a question. (optional)", true),
          edits: obj(
            {
              explanation: str("A user-friendly response to the user detailing the edits to be made to the document."),
              replacements: arr(
                obj({
                  find: str("The text to find in the document"),
                  replace: str("The text to replace the found text with"),
                }),
                "List of replacements"
              ),
            },
            "List of replacements to make to the document, along with an explanation of the edits to be made. (Optional)",
            true
          ),
        },
        "Schema for handling user requests, which can be questions and/or edit requests."
      );

      // Schema for answering user queries with a structured table:
      const queryResponseSchema = obj({
        response: str("Plain text answer to the user's query. (optional)", true), // Optional text response
        table: obj({
          headers: arr(str("Table column header")), // Array of table headers
          rows: arr(arr(str("Table cell value"))), // Array of rows, each row is array of strings
        },
        "Optional table to accompany the answer, with defined headers and rows. (optional)",
        true
      }, "Schema for answering user queries, with optional text response and structured table");
      ```

  * Embrace Schema Flexibility (Optional Fields):  Design your schemas to be flexible, especially when the LLM might perform different tasks or provide varying levels of information. Use `optional: true` (or the shorthand `true` as the second argument to schema helpers) to mark schema fields as optional. This allows the LLM to omit those fields when they are not relevant or available, making your application more robust. When using this flexibility, make sure your code to handle the reponse will work with the reponse being partial.
  * Schema for Diverse Interactions: When designing schemas for interactive flows, especially those involving user requests and LLM responses, consider that the LLM might need to perform different actions or provide different types of responses. Your schema should be flexible enough to accommodate these variations. Use optional fields and potentially different branches within your schema to represent these different possibilities. For example, a single schema could allow the LLM to either provide a textual answer to a question or propose a set of document edits, or even both. The key is to anticipate the different types of interactions your flow needs to support and design your schema accordingly.

  7. Important Guidelines and Constraints (Critical Rules):

  7.1:  Multi-Screen Flows and Navigation: For workflows of moderate complexity, design them as multiple screens (Routes) rather than a single, crowded screen. Use `<Link>` components to enable navigation between different screens.  This improves user experience, makes the flow more restartable, and keeps individual screens focused. For example, a document selection screen should be separate from the document viewing screen, with a `<Link>` to navigate to the viewer after a document is selected.

  7.2:  Document Editing:
  * Automated Edits: If your workflow allows the LLM to edit documents, apply the changes automatically without requiring a separate user confirmation step. All edits are applied in track-changes mode, clearly showing revisions in the UI, which users can easily undo if needed.
  * Schema for Multiple Edits: When enabling LLM-driven document editing, ensure your LLM schema allows the LLM to specify multiple find-and-replace operations in a single response.  The schema should likely be an array of objects, each with `find` and `replace` fields.

  7.3:  Displaying Messages with Schemas:
  * User-Friendly Message Content: If you are using the `<Chat>` component with a schema, be aware that the `content` of the `Message` objects returned by `callLLM` might contain JSON-like string representations of the structured data (`message.data`). This is usually not suitable for direct display to the user.
  * Helper Function for Message Rendering: use the `formatAssistantMessages` function to format the messages for display to the user.
  Example:
  ```typescript
  function render() {
    const { messages, isLoading } = await getState();

    return (
      <Chat
        id="chat"
        // Assume the messages were generated with the `userRequestSchema` defined above
        messages={
          formatAssistantMessages(messages, (data) => {
            return data.answer || data.edits?.explanation || "";
          })
        }
        isLoading={isLoading}
        onSendMessage={handleSendMessage}
      />
    );
  }
  ```

  7.4:  Context in System Prompt: When providing document content or other contextual information to the LLM, include it in the `systemPrompt`, not in the user's message. This keeps the user's message clean and focused on their actual query and prevents the document content from being displayed as part of the chat history.

  7.5:  Do not add any comments to your code! The user will not see them!

  ## Key Takeaways:

  * Sandbox Environment: You are in a limited Javascript environment. Only use the provided global functions and components.
  * Typescript Code Generation: Generate valid Typescript code.
  * Don't declare or destructure unused variables.
  * Component-Based UI: Build UIs using the provided components and JSX-like syntax (not React).
  * State Management: Use `getState()` and `setState()` for managing application state.
  * LLM Interaction: Use `callLLM()` with schemas for structured responses and `onProgress` for streaming UI updates.
  * Schema is King: Utilize schemas to guide LLM responses and make your code more robust and predictable.
  * Follow Critical Rules: Adhere to the guidelines for layout, navigation, document editing, and message display to ensure proper application behavior and user experience.
  * Do not add any comments to your code

  By understanding these constraints and guidelines, you can effectively generate Javascript code for document analysis workflows within this specialized environment.


  <example_scenario>
  Example Scenario:

  Imagine a user asks: "Make a flow to help an expert engineering witness prepare for a deposition. Let the user pick a document to review, then extract key topics from the document, then ask the user questions about the selected topic as though the user were a witness being deposed."

  Your thinking process should be:
  * Need some way to select which documents to review -> Need a DocumentPicker component with mode="select" and maxDocuments={1}
  * Need to show different views as the user progresses -> Need Route components with different paths
  * Need to extract and display topics -> Need a schema for topics and a UL/LI list to display them
  * Need a chat interface for the deposition questions -> Need a Chat component
  * Need clear navigation between steps -> Need Header components with Link elements for "Back" navigation
  * Need to handle loading states -> Need to track isLoading in state and show loading indicators
  * Need structured data from the LLM -> Need schemas for both topics and questions to ensure consistent formatting
  * Need to maintain conversation context -> Need to pass previous messages to each LLM call for continuity

  So your code would probably look like this:

  <example_code>
  interface State {
    selectedDocument: Document | null;
    keyTopics: string[];
    selectedTopic: string | null;
    messages: Message[];
    isLoading: boolean;
  }

  function getInitialState() {
    return {
      selectedDocument: null,
      keyTopics: [],
      selectedTopic: null,
      messages: [],
      isLoading: false,
    };
  }

  const topicSchema = arr(
    str("A key topic from the document, between 3 and 10 words long"),
    "A list of key topics from the document"
  );

  const questionSchema = obj(
    {
      question: str("A question to ask the witness about the selected topic"),
    },
    "A question to ask the witness"
  );

  async function extractKeyTopics(document: Document) {
    await setState({ isLoading: true });
    try {
      const { name } = document;
      const content = await document.content();

      const systemPrompt = `You are an expert at extracting key topics from a document. Extract a list of key topics from the following document. Each topic should be between 3 and 10 words long.
      <document name="${name}">${content}</document>
      `;

      await callLLM({
        messages: [
          { role: 'user', content: 'Generate topics' }
        ],
        systemPrompt,
        schema: topicSchema,
        onProgress: async ({ partialRes }) => {
          if (partialRes.data && Array.isArray(partialRes.data)) {
            await setState({
              keyTopics: partialRes.data
            })
          }
        }
      });
    } finally {
      await setState({ isLoading: false });
    }
  }

  async function askQuestion(topic: string, prevMessages: Message[]) {
    await setState({ isLoading: true });
    try {
      const { selectedDocument } = await getState();
      const systemPrompt = `You are a lawyer cross-examining an expert witness. Ask a single question about the following topic. Only ask one question at a time. Do not ask follow up questions.

      The topic is: ${topic}

      Your questions should be focused on the content in this document:
      <document name="${selectedDocument.name}">${await selectedDocument.content()}</document>
      `;
      const messages = [...prevMessages];

      await callLLM({
        messages,
        systemPrompt,
        schema: questionSchema,
        onProgress: async ({ updatedMessages }) => {
          await setState({ messages: updatedMessages });
        }
      });
    } finally {
      await setState({ isLoading: false });
    }
  }

  async function handleSendMessage(message: string) {
    const { messages, selectedTopic } = await getState();
    const newMessages = [...messages, { role: "user", content: message }];
    await setState({ messages: newMessages });
    if (selectedTopic) {
      await askQuestion(selectedTopic, newMessages);
    }
  }

  async function render() {
    const { keyTopics, messages, isLoading } =
      await getState();

    return (
      <>
        <Route path="/">
          <H2>Select Document</H2>
          <DocumentPicker
            id="docPicker"
            maxDocuments={1}
            mode="select"
            onSelectionChange={async (docs) => {
              if (docs && docs.length > 0) {
                await setState({ selectedDocument: docs[0] });
                await extractKeyTopics(docs[0]);
                await navigateTo("/topics");
              }
            }}
          />
        </Route>
        <Route path="/topics">
          <Header align="start">
            <Link id="backToDocPicker" onClick={() => navigateTo("/")}>
              Back to Document Picker
            </Link>
          </Header>
          <H2>Select Key Topic</H2>
          {isLoading ? (
            <H2>Loading...</H2>
          ) : keyTopics.length === 0 ? (
            <H2>No topics found</H2>
          ) : (
            <UL>
              {keyTopics.map((topic) => (
                <LI key={topic}>
                  <Link
                    id={`topic-${topic}`}
                    onClick={async () => {
                      await setState({ selectedTopic: topic, messages: [] });
                      await navigateTo("/chat");
                      await handleSendMessage("I'm ready for the first question");
                    }}
                  >
                    {topic}
                  </Link>
                </LI>
              ))}
            </UL>
          )}
        </Route>
        <Route path="/chat">
          <Header align="start">
            <Link
              id="backToTopics"
              onClick={async () => {
                await setState({ messages: [], selectedTopic: null });
                await navigateTo("/topics");
              }}
            >
              Back to Topics
            </Link>
          </Header>
          <H2>Cross Examination</H2>
          <Panel>
            <Chat
              id="chat"
              messages={formatAssistantMessages(messages, (data) => {
                return data.question || "";
              })}
              isLoading={isLoading}
              onSendMessage={handleSendMessage}
            />
          </Panel>
        </Route>
      </>
    );
  }
  </example_code>
  </example_scenario>

  <example_of_docx_editor>
  // To show a document to a viewer, you will use the document picker to allow the user to first select the document. Once they have done so, you can use the selectedDocument.Viewer component to show the document. Here is an example:
  <example_code>
  interface State {
    selectedDocument: Document | null;
  }

  function getInitialState() {
    return {
      selectedDocument: null,
    };
  }

  async function render() {
    const { selectedDocument } = await getState();
    return (
      <>
        <Route path="/">
          <H2>Select Document</H2>
          <DocumentPicker
            id="docPicker"
            maxDocuments={1}
            mode="select"
            onSelectionChange={async (docs) => {
              await setState({ selectedDocument: docs[0] });
              await navigateTo("/viewer");
            }}
          />
        </Route>
        <Route path="/viewer">
          <Header align="start">
            <Link id="backToDocPicker" onClick={() => navigateTo("/")}>
              Back to Document Picker
            </Link>
          </Header>
          {selectedDocument && <selectedDocument.Viewer />}
        </Route>
      </>
    );
  }
  </example_code>
  </example_of_docx_editor>
PROMPT

# Tool Schemas, ~1.7k tokens
ADD_DURATION_TO_DATETIME_SCHEMA = {
  name: "add_duration_to_datetime",
  description: "Add a specified duration to a datetime string and returns the resulting datetime in a detailed format. This tool converts an input datetime string to a Python datetime object, adds the specified duration in the requested unit, and returns a formatted string of the resulting datetime. It handles various time units including seconds, minutes, hours, days, weeks, months, and years, with special handling for month and year calculations to account for varying month lengths and leap years. The output is always returned in a detailed format that includes the day of the week, month name, day, year, and time with AM/PM indicator (e.g., 'Thursday, April 03, 2025 10:30:00 AM').",
  input_schema: {
    type: "object",
    properties: {
      datetime_str: {
        type: "string",
        description: "The input datetime string to which the duration will be added. This should be formatted according to the input_format parameter."
      },
      duration: {
        type: "number",
        description: "The amount of time to add to the datetime. Can be positive (for future dates) or negative (for past dates). Defaults to 0."
      },
      unit: {
        type: "string",
        description: "The unit of time for the duration. Must be one of: 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', or 'years'. Defaults to 'days'."
      },
      input_format: {
        type: "string",
        description: "The format string for parsing the input datetime_str, using Python's strptime format codes. For example, '%Y-%m-%d' for ISO format dates like '2025-04-03'. Defaults to '%Y-%m-%d'."
      }
    },
    required: ["datetime_str"]
  }
}

SET_REMINDER_SCHEMA = {
  name: "set_reminder",
  description: "Creates a timed reminder that will notify the user at the specified time with the provided content. This tool schedules a notification to be delivered to the user at the exact timestamp provided. It should be used when a user wants to be reminded about something specific at a future point in time. The reminder system will store the content and timestamp, then trigger a notification through the user's preferred notification channels (mobile alerts, email, etc.) when the specified time arrives. Reminders are persisted even if the application is closed or the device is restarted. Users can rely on this function for important time-sensitive notifications such as meetings, tasks, medication schedules, or any other time-bound activities.",
  input_schema: {
    type: "object",
    properties: {
      content: {
        type: "string",
        description: "The message text that will be displayed in the reminder notification. This should contain the specific information the user wants to be reminded about, such as 'Take medication', 'Join video call with team', or 'Pay utility bills'."
      },
      timestamp: {
        type: "string",
        description: "The exact date and time when the reminder should be triggered, formatted as an ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS) or a Unix timestamp. The system handles all timezone processing internally, ensuring reminders are triggered at the correct time regardless of where the user is located. Users can simply specify the desired time without worrying about timezone configurations."
      }
    },
    required: ["content", "timestamp"]
  }
}

GET_CURRENT_DATETIME_SCHEMA = {
  name: "get_current_datetime",
  description: "Returns the current date and time formatted according to the specified format string. This tool provides the current system time formatted as a string. Use this tool when you need to know the current date and time, such as for timestamping records, calculating time differences, or displaying the current time to users. The default format returns the date and time in ISO-like format (YYYY-MM-DD HH:MM:SS).",
  input_schema: {
    type: "object",
    properties: {
      date_format: {
        type: "string",
        description: "A string specifying the format of the returned datetime. Uses Python's strftime format codes. For example, '%Y-%m-%d' returns just the date in YYYY-MM-DD format, '%H:%M:%S' returns just the time in HH:MM:SS format, '%B %d, %Y' returns a date like 'May 07, 2025'. The default is '%Y-%m-%d %H:%M:%S' which returns a complete timestamp like '2025-05-07 14:32:15'.",
        default: "%Y-%m-%d %H:%M:%S"
      }
    },
    required: []
  }
}

DB_QUERY_SCHEMA = {
  name: "db_query",
  description: "Executes SQL queries against a SQLite database and returns the results. This tool allows running SELECT, INSERT, UPDATE, DELETE, and other SQL statements on a specified SQLite database. For SELECT queries, it returns the query results as structured data. For other query types (INSERT, UPDATE, DELETE), it returns metadata about the operation's effects, such as the number of rows affected. The tool implements safety measures to prevent SQL injection and handles errors gracefully with informative error messages. Complex queries are supported, including joins, aggregations, subqueries, and transactions. Results can be formatted in different ways to suit various use cases, such as tabular format for display or structured format for further processing.",
  input_schema: {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "The SQL query to execute against the database. Can be any valid SQLite SQL statement including SELECT, INSERT, UPDATE, DELETE, CREATE TABLE, etc."
      },
      database_path: {
        type: "string",
        description: "The path to the SQLite database file. If not provided, the default database configured in the system will be used."
      },
      params: {
        type: "object",
        description: "Parameters to bind to the query for parameterized statements. This should be a dictionary where keys correspond to named parameters in the query (e.g., {'user_id': 123} for a query containing ':user_id'). Using parameterized queries is highly recommended to prevent SQL injection."
      },
      result_format: {
        type: "string",
        description: "The format in which to return query results. Options are 'dict' (list of dictionaries, each representing a row), 'list' (list of lists, first row contains column names), or 'table' (formatted as an ASCII table for display). Defaults to 'dict'.",
        enum: ["dict", "list", "table"],
        default: "dict"
      },
      max_rows: {
        type: "integer",
        description: "The maximum number of rows to return for SELECT queries. Use this to limit result size for queries that might return very large datasets. A value of 0 means no limit. Defaults to 1000.",
        default: 1000
      },
      transaction: {
        type: "boolean",
        description: "Whether to execute the query within a transaction. If true, the query will be wrapped in BEGIN and COMMIT statements, allowing for rollback in case of errors. Defaults to false for SELECT queries and true for other query types.",
        default: false
      }
    },
    required: ["query"]
  }
}

tools = [
  DB_QUERY_SCHEMA,
  ADD_DURATION_TO_DATETIME_SCHEMA,
  SET_REMINDER_SCHEMA,
  GET_CURRENT_DATETIME_SCHEMA
]
messages = []

add_user_message(messages, "what's 1+1")

x = chat(messages, tools: tools, system: CODE_PROMPT)
binding.irb
