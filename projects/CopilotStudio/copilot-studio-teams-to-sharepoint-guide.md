# Copilot Studio / Power Automate: Teams Channel Message to SharePoint List

This guide assumes your bot or Copilot Studio flow is using Power Automate actions under the hood.

## What you are building

Goal:

1. Capture a Teams channel message
2. Pull out the useful message details
3. Create a new row in a SharePoint list

In practice, this is usually:

- Trigger: `Microsoft Teams`
- Action: optional cleanup/formatting steps
- Action: `SharePoint -> Create item`

## First decision: automatic vs manual

There are two common ways to start this:

### Option A: automatic capture

Use the Teams trigger:

- `When a new channel message is added`

Use this if you want every new top-level message in a channel to be logged.

Important:

- This trigger only catches root channel posts.
- It does not fire for replies to an existing thread.

### Option B: manual capture

Use the Teams trigger:

- `For a selected message (V2)`

Use this if a user should manually choose which message gets saved.

This is often easier for testing because you can right-click or use `More actions` on a Teams message and run the flow only when needed.

## What the `Create item` action means

Microsoft's SharePoint connector defines `Create item` like this:

- `Site Address`: the SharePoint site URL
- `List Name`: the target list
- `Item`: the column values for the new list row

In the designer, after you pick the site and the list, the action expands into one input box per SharePoint column.

So if your SharePoint list has columns like:

- `Title`
- `MessageText`
- `SenderName`
- `SenderId`
- `CreatedOn`
- `MessageLink`
- `TeamName`
- `ChannelName`

Then the `Create item` action is really asking:

- what value should go into `Title`?
- what value should go into `MessageText`?
- what value should go into `SenderName`?
- and so on

The formatted code view looks dense because it is storing all those mappings as JSON-like parameters.

## Mental model for the code view

If the code view shows something like this:

```json
{
  "host": {
    "connectionReferenceName": "shared_sharepointonline",
    "operationId": "PostItem"
  },
  "parameters": {
    "dataset": "https://contoso.sharepoint.com/sites/Operations",
    "table": "Teams Message Log",
    "item/Title": "@{triggerBody()?['body']?['plainTextContent']}",
    "item/SenderName": "@{triggerBody()?['from']?['user']?['displayName']}"
  }
}
```

Read it like this:

- `dataset` = SharePoint site
- `table` = SharePoint list
- `item/ColumnName` = value being written into that SharePoint column

That is the whole trick.

## Recommended simple list schema

If you are allowed to shape the SharePoint list, start simple:

- `Title` (single line of text)
- `MessageText` (multiple lines of text)
- `SenderName` (single line of text)
- `SenderEmail` (single line of text)
- `MessageCreated` (date/time)
- `MessageLink` (hyperlink or single line of text)
- `TeamId` (single line of text)
- `ChannelId` (single line of text)
- `MessageId` (single line of text)

This avoids complex SharePoint field types while you get the flow working.

## Recommended flow shape

### Version 1: simplest reliable path

1. Teams trigger
   - `When a new channel message is added`
2. Optional data cleanup
   - `Compose` for plain text body
3. SharePoint
   - `Create item`

### Inside `Create item`

Map fields roughly like this:

- `Site Address` -> your SharePoint site URL
- `List Name` -> your list name
- `Title` -> first 100-255 chars of the message, or a timestamped label
- `MessageText` -> message body text
- `SenderName` -> sender display name
- `MessageCreated` -> created timestamp
- `MessageId` -> message id
- `TeamId` -> team id
- `ChannelId` -> channel id
- `MessageLink` -> message link, if exposed by your trigger

## If the message body is HTML

Teams message content is often returned as HTML, not plain text.

That means you may see values like:

```html
<div>Hello team<br>Need help with item 123</div>
```

If you store that directly in SharePoint, it may look ugly.

Use one of these approaches:

### Approach 1: use a plain text token if available

Some Teams triggers expose a plain text field directly. If you see one in dynamic content, use that.

### Approach 2: use `Html to text`

Add a content conversion step before `Create item`:

1. Add action: `Content Conversion -> Html to text`
2. Input: Teams message content
3. Use that output in SharePoint `MessageText`

This is usually the cleanest option.

## Example mapping patterns

Your actual token names may differ, but these are the kinds of values you want:

### Title

Good choices:

- first part of the message
- sender plus timestamp
- a fixed label like `Teams Channel Message`

Example expression:

```text
substring(outputs('Html_to_text'), 0, 100)
```

Safer if the message can be short:

```text
if(greater(length(outputs('Html_to_text')),100),substring(outputs('Html_to_text'),0,100),outputs('Html_to_text'))
```

### Message text

Use:

```text
outputs('Html_to_text')
```

or a plain text dynamic token from the Teams trigger.

### Sender name

Use the sender display name token from the Teams trigger.

In expression form it often looks conceptually like:

```text
triggerBody()?['from']?['user']?['displayName']
```

### Created timestamp

Use the message creation time token.

Conceptually:

```text
triggerBody()?['createdDateTime']
```

### Message ID

Conceptually:

```text
triggerBody()?['id']
```

## Very common reasons `Create item` feels confusing

### 1. The SharePoint columns do not appear

Usually one of these:

- Site Address is not selected yet
- List Name is not selected yet
- the list is a custom template instead of a normal list
- the connection needs to be refreshed

Fix:

1. Select `Site Address`
2. Select `List Name`
3. Wait for the action to expand
4. If it still does not, delete and re-add the action

### 2. The field names in code do not match the display names exactly

SharePoint often uses internal column names behind the scenes.

So the code may reference something that looks slightly different from the label you see in SharePoint.

That is normal.

### 3. Person, Choice, or Lookup columns fail

Those are more complex column types.

For your first pass, avoid them if possible.

Use plain text columns first so the flow works end to end.

### 4. The trigger gives HTML and SharePoint stores junk

Use `Html to text` before `Create item`.

### 5. Replies are missing

The `When a new channel message is added` trigger does not catch replies.

If you need replies too, the design usually gets more complicated and may require Graph-based handling or a different trigger pattern.

## A practical starter configuration

If I were setting up the first working version, I would do this:

### Trigger

- `When a new channel message is added`
- choose Team
- choose Channel

### Action

- `Html to text`
- content = Teams message content

### SharePoint action

- `Create item`
- `Site Address` = your site
- `List Name` = your list

Field mapping:

- `Title` = `if(greater(length(outputs('Html_to_text')),100),substring(outputs('Html_to_text'),0,100),outputs('Html_to_text'))`
- `MessageText` = `outputs('Html_to_text')`
- `SenderName` = sender display name token
- `MessageCreated` = created datetime token
- `MessageId` = message id token
- `TeamId` = team id token if available
- `ChannelId` = channel id token if available

## If you are doing this from Copilot Studio

If your Copilot calls a flow:

1. Build and test the cloud flow first in Power Automate
2. Confirm the SharePoint row is created correctly
3. Only then wire that flow into Copilot Studio as an action

That avoids debugging both layers at once.

If you try to solve trigger logic, token mapping, and Copilot orchestration at the same time, it gets confusing fast.

## What to send me so I can get more exact

If you want, send me any of these:

- the names and types of your SharePoint columns
- the exact trigger name you used
- a pasted redacted version of the `Create item` code view
- the dynamic content labels you see in the designer
- the exact error text, if it is failing

If you paste the `Create item` block, I can translate it line by line into plain English.

## Current references

- Microsoft Teams connector docs: https://learn.microsoft.com/en-us/connectors/teams/
- Teams `For a selected message` article: https://learn.microsoft.com/en-us/power-automate/trigger-flow-teams-message
- SharePoint connector docs: https://learn.microsoft.com/en-us/connectors/sharepoint/
