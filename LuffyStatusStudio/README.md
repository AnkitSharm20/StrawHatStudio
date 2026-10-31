# Luffy Status Studio

A lightweight Windows companion for Straw Hat Studio. It uses Discord's local desktop RPC pipe and the public Application ID configured for this project.

## Requirements

- Windows 10 or 11
- Node.js 20 or newer
- Discord desktop app running and signed in
- Discord application ID: `1565366157559595099`

## Run

1. Open Discord desktop.
2. Extract this folder.
3. Open PowerShell in this folder.
4. Run `node companion.mjs`.
5. The control panel opens at `http://127.0.0.1:47831`.
6. Choose a preset or create one and press **Set Discord Presence**.

No Discord bot token, user token, or client secret is needed. Presets are stored in `presets.json` on this PC.

## Important Discord limitation

Discord RPC supports Playing, Listening, Watching, and Competing activity types. It does not provide a literal Streaming activity type through `SET_ACTIVITY`, and it does not set the separate Custom Status bubble. This companion therefore displays **STREAMING LUFFY** as the Rich Presence Details line, with **Watching** or **Playing** as the activity type. To show the application label as **L U F F Y**, configure that public name in the Discord Developer Portal for this application.

This is not a BetterDiscord plugin and does not patch Discord's files or internal client code. The BetterDiscord sample you supplied is a third-party client modification and its custom-status editing is not reproduced here.

## Troubleshooting

- If the status says Discord is not connected, open or restart Discord desktop, then restart the companion.
- Keep the terminal window open while using the companion.
- Close with Ctrl+C to clear the Rich Presence.
- Use HTTPS image URLs. Discord may not render every external image host; uploading approved assets to the Discord Developer Portal is the most reliable route.
