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
