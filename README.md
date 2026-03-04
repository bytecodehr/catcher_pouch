# CatcherPouch

A mountable Rails engine that discovers your mailers, previews emails with sample data, and lets you edit ERB templates live from your admin panel.

## Features

- **Automatic mailer discovery** — finds all `ActionMailer::Base` descendants including Devise mailers, with template-based action detection for inherited methods
- **Live email preview** — renders real emails using configurable sample data procs, displayed in a sandboxed iframe
- **Template editor** — CodeMirror 5 with syntax highlighting (HTML/ERB/Ruby/CSS), code folding, bracket matching, and auto-close tags
- **Keyboard shortcuts** — Cmd+S / Ctrl+S to save directly from the editor
- **ERB validation** — syntax-checks templates before saving to prevent broken emails
- **Template deduplication** — when app-level templates override gem defaults (e.g. Devise), only the app version is shown
- **Host layout integration** — renders inside your existing admin layout with full access to host route helpers, view helpers, and partials
- **Authorization** — configurable lambda to restrict access (e.g. admin-only)
- **Read-only mode** — disable editing in production while keeping preview functionality
- **Standalone fallback layout** — works without a host layout using built-in DaisyUI/Tailwind styling

## Requirements

- Ruby >= 3.1
- Rails >= 7.0

## Installation

Add CatcherPouch to your Gemfile. Since this is typically only needed in development and staging environments:

```ruby
group :development, :staging do
  gem "catcher_pouch", github: "bytecodehr/catcher_pouch", branch: "main"
end
```

Then run:

```sh
bundle install
```

## Setup

### 1. Mount the engine

In your `config/routes.rb`, mount the engine under your admin namespace:

```ruby
Rails.application.routes.draw do
  # Mount under your admin area (adjust path as needed)
  mount CatcherPouch::Engine, at: "/backoffice/email-templates" if defined?(CatcherPouch)
end
```

The `if defined?(CatcherPouch)` guard ensures the route only exists when the gem is loaded (i.e. not in production if you've scoped it to `:development, :staging`).

### 2. Configure the engine

Create an initializer at `config/initializers/catcher_pouch.rb`:

```ruby
if defined?(CatcherPouch)
  CatcherPouch.configure do |config|
    # Authorization: receives the controller instance, return true to allow access.
    # Default: ->(_controller) { true } (no restriction)
    config.authorization = lambda { |controller|
      admin = controller.respond_to?(:current_admin, true) && controller.send(:current_admin)
      admin&.superadmin? || admin&.admin?
    }

    # Layout: set to your admin layout name to integrate with your existing UI.
    # Set to nil to use the built-in standalone layout.
    # Default: nil
    config.layout = "backoffice"

    # Editable: whether templates can be saved to disk.
    # Default: !Rails.env.production?
    config.editable = Rails.env.development? || Rails.env.staging?

    # Previews: sample data for rendering email previews.
    # Hash of mailer_class_name => { action_name => lambda_returning_mail_object }
    config.previews = {
      "UserMailer" => {
        "confirmation_code" => lambda {
          user = User.first || User.new(email: "preview@example.com", confirmation_code: "123456")
          UserMailer.confirmation_code(user)
        }
      },
      "Devise::Mailer" => {
        "invitation_instructions" => lambda {
          admin = Admin.first || Admin.new(email: "admin@example.com")
          Devise::Mailer.invitation_instructions(admin, "sample-token-abc123")
        }
      }
    }
  end
end
```

## Configuration Options

| Option          | Type     | Default                        | Description                                                    |
|-----------------|----------|--------------------------------|----------------------------------------------------------------|
| `authorization` | Lambda   | `->(_c) { true }`             | Receives the controller instance. Return `true` to allow access, `false` to deny (renders 403). |
| `layout`        | String   | `nil`                          | Host app layout name (e.g. `"backoffice"`). `nil` uses the built-in standalone layout.           |
| `editable`      | Boolean  | `!Rails.env.production?`       | Whether templates can be edited and saved to disk.              |
| `previews`      | Hash     | `{}`                           | Nested hash of `"MailerClass" => { "action" => -> { MailerClass.action(...) } }` lambdas.       |

## Pages

### Mailer Index

Lists all discovered mailers as cards showing action count, template count, and a link to view details.

**Route:** Engine root (e.g. `/backoffice/email-templates`)

### Mailer Show

Displays a single mailer's actions with:
- **Preview** button — opens the rendered email HTML in a new tab
- **Edit/View** button — opens the template editor (or read-only viewer)
- Format badges (html/text) for each template file

**Route:** `/backoffice/email-templates/mailers/:mailer_class`

### Template Editor

Split-pane view with:
- **Left:** CodeMirror editor with ERB/HTML syntax highlighting, Dracula theme, code folding
- **Right:** Live preview iframe showing the rendered email
- **Top bar:** Email metadata (subject, from, to) extracted from the preview
- **Save** button and Cmd+S keyboard shortcut (when editable)
- ERB syntax validation on save — invalid templates are rejected with an error message

**Route:** `/backoffice/email-templates/templates/show?path=...`

### Template Preview

Renders the email HTML in isolation (no layout wrapper). Used by the preview iframe and the "Preview" button that opens in a new tab.

**Route:** `/backoffice/email-templates/templates/preview?path=...`

## How It Works

### Mailer Discovery

`CatcherPouch::MailerDiscovery` uses Zeitwerk eager loading to find all `ActionMailer::Base` descendants. Actions are discovered via two strategies:

1. **Instance methods** — public methods defined directly on the mailer class
2. **Template scanning** — parses template directories for action names, which catches inherited actions (e.g. `invitation_instructions` from `DeviseInvitable::Mailer`)

### Template Deduplication

When a gem (like Devise) ships its own templates and your app overrides them in `app/views/`, CatcherPouch tags each template with `app_template: true/false` and deduplicates by `relative_path`, preferring the app-level version.

### Host Layout Integration

CatcherPouch uses `isolate_namespace` for clean engine isolation. To make host app route helpers (e.g. `backoffice_account_path`) available in engine views rendered within the host layout, the engine's `ApplicationController` includes a `HOST_ROUTE_DELEGATOR` module that delegates unknown helper methods to `main_app`. Engine route helpers take priority since they're already defined; `method_missing` only fires for host app helpers.

### Preview Rendering

`CatcherPouch::TemplateRenderer` calls your configured preview lambdas and handles both `Mail::Message` and `ActionMailer::MessageDelivery` return types. It extracts HTML/text parts, subject, from, and to fields. Errors are caught and displayed gracefully in the UI.

## Writing Preview Lambdas

Preview lambdas should return a `Mail::Message` (or `ActionMailer::MessageDelivery`). Use real records when available with fallbacks:

```ruby
config.previews = {
  "OrderMailer" => {
    "receipt" => lambda {
      order = Order.last || Order.new(id: 1, total: 99.99)
      OrderMailer.receipt(order)
    },
    "shipping_notification" => lambda {
      order = Order.last || Order.new(id: 1, tracking_number: "1Z999AA10123456784")
      OrderMailer.shipping_notification(order)
    }
  }
}
```

If a preview lambda is not configured for an action, CatcherPouch displays a helpful message pointing you to the configuration.

## License

MIT License. Copyright (c) 2026 [Bytecode Agency](https://bytecodeagency.com).
