# RebuffedMessanger

A separate whisper interface for WoW 3.3.5a, with a shared contact list and detachable conversation windows.

## Installation

Close WoW, copy the `RebuffedMessanger` folder into `Interface/AddOns/`, then restart the game and enable the addon. No other addons are required.

## Conversations

Incoming whispers open the messenger without taking keyboard focus. Click a name in the left-hand list to switch conversations. Unread messages in other conversations are counted next to the name.

Drag a name out of the list and release it to open a separate window, or click **Abtrennen / Detach** in the conversation. Each detached window has its own input box. **Andocken / Attach** returns it to the shared window. Closing a detached window also returns the contact to the shared list.

Type a message and press Enter or click **Senden / Send**. Escape releases keyboard focus. Messages are sent only when you submit them. Item and other game links remain clickable.

To start a conversation, enter a name in the contact field and click **+**, use `/rmsg Name`, choose Whisper from the normal player menu, or type `/w Name ` in chat. The normal Reply and Reply-to-last-recipient bindings also open the messenger. Whispers sent from the standard chat or another addon appear in the messenger when the server confirms them.

Typed whisper drafts are moved from the standard chat when the recipient is known. If both interfaces already hold separate nonempty drafts for that recipient, the standard input is left in place so neither draft is overwritten.

## Commands

- `/rmsg` opens the shared window.
- `/rmsg Name` opens a conversation and focuses its input.
- `/messanger` is an alias for `/rmsg`.

Drag a window's header to move it. Positions are saved per character. Conversation text and drafts are kept only for the current session, with up to 150 messages per contact; they are not written to SavedVariables. The original chat's whisper lines are hidden while this addon is enabled.

## Updates

Version checks run inside WoW using the same shared version protocol as the other Rebuffed addons. A newer version must be confirmed by two different players in your party, raid or guild. Confirmed versions are remembered for later logins. `/rebuffedupdates` shows version information. Downloads and installation remain manual.
