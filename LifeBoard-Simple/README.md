# LifeBoard Simple

A simple, human-readable personal planning application built with pure Java, HTML, CSS, and JavaScript.

## Features

- **Calendar & Tasks** - Daily task management with steps and priorities
- **Inventory** - Track your belongings with quantity management
- **Shopping Lists** - Create and manage shopping lists, auto-generate from low inventory
- **Budget** - Track income and expenses with summary views
- **Notes** - Notebooks and pages for your thoughts
- **Goals** - Goal tracking with milestones and progress
- **Habits** - Daily habit tracking with completion history
- **Tags** - Organize everything with a flexible tagging system

## Tech Stack

- **Backend**: Pure Java with embedded HTTP server (no frameworks)
- **Database**: SQLite (single file, no installation needed)
- **Frontend**: Vanilla HTML, CSS, JavaScript (no build tools)

## Requirements

- Java JDK 11 or higher

## Quick Start

1. **Compile the application**:
   ```batch
   compile.bat
   ```
   This will download the SQLite JDBC driver and compile all Java files.

2. **Run the server**:
   ```batch
   run.bat
   ```

3. **Open your browser**:
   Navigate to `http://localhost:8080`

4. **Create an account** and start planning!

## Project Structure

```
LifeBoard-Simple/
├── src/                      # Java source code
│   ├── Main.java             # HTTP server entry point
│   ├── db/
│   │   └── Database.java     # SQLite database manager
│   ├── handlers/             # API endpoint handlers
│   │   ├── AuthHandler.java
│   │   ├── TaskHandler.java
│   │   ├── InventoryHandler.java
│   │   ├── ShoppingHandler.java
│   │   ├── BudgetHandler.java
│   │   ├── NotesHandler.java
│   │   ├── GoalsHandler.java
│   │   ├── HabitsHandler.java
│   │   ├── TagsHandler.java
│   │   ├── NotificationsHandler.java
│   │   └── PreferencesHandler.java
│   └── util/
│       ├── JsonUtil.java     # JSON parser/builder
│       └── SessionUtil.java  # Session management
├── web/                      # Static frontend files
│   ├── index.html            # Dashboard
│   ├── css/
│   │   ├── main.css          # Core styles
│   │   ├── components.css    # UI components
│   │   └── themes.css        # Dark/light themes
│   ├── js/
│   │   ├── api.js            # API client
│   │   └── app.js            # Main application
│   └── pages/
│       └── login.html        # Login/register page
├── data/                     # Database storage
│   └── lifeboard.db          # SQLite database (created on first run)
├── compile.bat               # Build script
├── run.bat                   # Start script
└── README.md                 # This file
```

## API Endpoints

All API endpoints are prefixed with `/api/`:

| Feature | Endpoints |
|---------|-----------|
| Auth | `POST /login`, `POST /register`, `GET /me` |
| Tasks | `GET/POST /tasks`, `GET/PUT/DELETE /tasks/{id}` |
| Inventory | `GET/POST /inventory/sheets`, `POST /inventory/items` |
| Shopping | `GET/POST /shopping-lists`, `POST /shopping-lists/generate` |
| Budget | `GET/POST /budget/sources`, `GET/POST /budget/entries` |
| Notes | `GET/POST /notebooks`, `GET/PUT/DELETE /pages/{id}` |
| Goals | `GET/POST /goals`, `POST /goals/{id}/milestones` |
| Habits | `GET/POST /habits`, `POST /habits/{id}/complete` |
| Tags | `GET/POST /tags`, `GET /tags/search` |

## Design Philosophy

This application was built with **human readability** as the primary goal:

1. **No frameworks** - Just standard Java and JavaScript
2. **No build tools** - No npm, no webpack, no compilation for frontend
3. **Modular code** - Each feature has its own handler and module
4. **Clear naming** - Variables and functions named for clarity
5. **Extensive comments** - Every file explains its purpose

The code is designed so that anyone with basic programming knowledge can:
- Understand how it works
- Modify it to their needs
- Add new features easily

## Customization

### Change the port
Edit `Main.java` and change the `PORT` constant.

### Add a new feature
1. Create a new handler in `src/handlers/`
2. Add database tables in `Database.java`
3. Register routes in `Main.java`
4. Create API methods in `web/js/api.js`
5. Build the UI in `web/pages/`

### Change the theme
Edit `web/css/themes.css` to customize colors.

## License

MIT - Use freely for any purpose.
