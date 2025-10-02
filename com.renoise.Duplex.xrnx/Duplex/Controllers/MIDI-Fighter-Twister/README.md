# Duplex for MidiFighter Twister

## One twister

Use the Effects and Mix, use the factory flash, on Bank 1.

## Two twisters

- Flash the twisters with the `.mfs` files.
- Use a midi router (Bome Translator Pro for example)...
  - Create two virtual MIDI devices (merger, and splitter)
  - Route the two midi fighter outputs to `merger`
  - Route `splitter` to the two midi fighter inputs
- In the settings, use `merger` as an input and splitter as an output
- The control surface lives on Bank 4.