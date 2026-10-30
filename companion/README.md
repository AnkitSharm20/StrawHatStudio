# Straw Hat Presence Companion — implementation plan

The companion is a separate desktop process because browser tabs cannot keep Discord Rich Presence alive after they close.

1. Create a Discord application in the Discord Developer Portal and enable Rich Presence.
2. Add the application ID to a native companion build configuration (never expose bot/client secrets in the website).
3. Implement Discord RPC using a maintained, supported desktop RPC library and the application's approved activity assets.
4. Keep the companion running in the system tray while Discord is open; provide pause, stop, privacy and uninstall controls.
5. Website-to-companion communication should use an authenticated localhost bridge with strict origin allowlisting, random pairing codes, short-lived tokens and no arbitrary command execution.

The website currently provides the configuration UI and setup guide only. No fake Discord activity is sent.
