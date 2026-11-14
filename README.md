# Pocket Pet

Pocket Pet is a small alien that lives on your iPhone. It starts as a speckled star egg, hatches into a round baby, and grows into a star, a cloud, or a spiky form depending on how you look after it. Hunger, happiness, and energy change even while the app is closed. You can feed it, play with it, and put it to sleep. If it is left empty or lonely for too long, it flies home to its planet, leaves a letter, and a new star egg arrives with a little gift from the one who left.

There is no account and no server. The pet is saved on the phone. A home screen widget can show the same pet.

The alien is drawn with simple shapes in a pastel lavender palette, so it can be replaced with real artwork later. The pictures live in `Shared/Art`. The sparkles button opens the star book, which lists every form you have raised and the letters left behind.

## How the pet behaves

All three meters are "higher is better." **Fed** at 100 means they just ate. **Happy** at 100 means they feel great. **Energy** at 100 means they are wide awake.

While they are awake, the meters slowly fall. A full pet gets hungry in about 10 hours, lonely a little more slowly, and tired in about 8 hours. If energy hits zero, they fall asleep on their own.

Sleep fills energy back up (a nap from empty takes a little over 3 hours). They still get hungry while they sleep, but more slowly. Happiness stays where it is. They wake up on their own when energy is full.

Feed fills them up. If they are already very full, extra food makes them a bit less happy. Play cheers them up and costs energy. They will not play when they are too tired or asleep.

Growth, from the moment you name them:

- Egg: 45 minutes, then they hatch
- Baby: 6 hours, then they grow into one adult form
- Star: balanced meals and play, without long empty meters
- Cloud: lots of extra treats, or lots of play and few steady meals
- Spiky: no care, or Fed and Happy left empty for a long time

If **Fed** or **Happy** sits at zero for 4 hours, they fly home. You see them wave from a little ship, read their letter, and meet the new egg. The new egg keeps one gift: a color tint and a small bonus to one meter. Nothing is sent off the phone.

## What you need

- A Mac with Xcode installed (the version that runs iOS 17 or newer)
- An Apple ID, the free kind is enough to run on the Simulator and on your own iPhone
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which builds the Xcode project from `project.yml`

This folder does not contain an `.xcodeproj` yet. You generate it. That keeps the project file from drifting away from `project.yml`.

## Open the project

1. Install Xcode from the Mac App Store and open it once so it can finish installing.
2. Install XcodeGen. In Terminal:

   ```bash
   brew install xcodegen
   ```

   If you don't have Homebrew, install it from [brew.sh](https://brew.sh), then run that command again.

3. In Terminal, go to this folder (the one that contains `project.yml`) and run:

   ```bash
   xcodegen generate
   ```

4. Open the project:

   ```bash
   open PocketPet.xcodeproj
   ```

   You can also double-click `PocketPet.xcodeproj` in Finder.

5. If Xcode asks you to trust the project, trust it.

The app target is **PocketPet**. The widget target is **PocketPetWidget**. You usually don't run the widget target by itself.

## Run it in the Simulator

1. At the top of Xcode, set the scheme to **PocketPet** (not "PocketPet Free Device").
2. Next to the scheme, choose an iPhone simulator, for example iPhone 15.
3. Press the Run button (the triangle), or press Command-R.
4. The app opens. Type a name, or leave it blank to use Mochi, then tap **Start the egg**.

The first time, Xcode may ask you to sign in. Use Xcode → Settings → Accounts, add your Apple ID, and on both **PocketPet** and **PocketPetWidget** (click the project in the left sidebar, then each target, then Signing & Capabilities) choose your name under Team. It will say Personal Team. Signing style should stay on Automatic.

The normal **PocketPet** scheme is the one that shares the pet with the widget. Use it for the Simulator.

## Run it on your iPhone

A free Apple ID can install the app on your own phone for about 7 days. After that, plug the phone back in and press Run again. Apple does not let a free Personal Team use App Groups, and the widget needs an App Group to read the pet. So there are two schemes:

- **PocketPet** — full app, including the shared widget. Use this on the Simulator. On a real iPhone it only signs if your team is allowed to use App Groups (a paid Apple Developer Program membership).
- **PocketPet Free Device** — the same app, without the App Group entitlement, so a free Personal Team can install it on your iPhone. The pet, the timers, reminders, and the debug menu all work. The home screen widget can be added, but it will say to open the app, because it cannot see the saved pet.

### Steps for your iPhone

1. Change the bundle id first, so it doesn't clash with someone else's. See [Change the bundle id](#change-the-bundle-id) below. Use something like `com.yourname.pocketpet`.
2. Connect the iPhone with a cable and unlock it. If the phone asks you to trust the computer, tap Trust.
3. In Xcode, choose the scheme **PocketPet Free Device**.
4. Choose your iPhone in the device menu next to the scheme.
5. Select the **PocketPet** target, open Signing & Capabilities, and set Team to your Personal Team. Do the same for **PocketPetWidget**. Leave "Automatically manage signing" on.
6. Press Run.
7. On the iPhone, if the app won't open: go to Settings → General → VPN & Device Management (on some iOS versions it is called Device Management), tap your Apple ID, and tap Trust.

The pet is saved on the phone. Deleting the app deletes the pet.

## Add the widget

The widget shows the pet and the three meters. It only stays in step with the app when both of them can read the shared App Group. That works with the **PocketPet** scheme on the Simulator.

1. Run the app once with the **PocketPet** scheme and start an egg.
2. Go to the home screen.
3. Touch and hold the wallpaper until the icons jiggle.
4. Tap the + button.
5. Search for **Pocket Pet**.
6. Choose the small or medium widget and add it.

If Pocket Pet is not in the list, use the **PocketPet** scheme, choose Product → Clean Build Folder, run the app again, and look once more.

On a free-team iPhone install (**PocketPet Free Device**), you can still add the widget, but it cannot see the pet. That is an Apple limit on free accounts, not a bug in the save file. The pet itself is fine inside the app.

## Turn on reminders

The app does not ask for notification permission on the first screen. After you name the pet, a card asks if you want a nudge when they need you.

1. Tap **Allow reminders** and accept the system prompt.
2. Reminders are local. Nothing is sent to a server.
3. The app plans them from the meters: getting hungry, feeling down, getting sleepy, hatching, and a warning before they would pass on.
4. Those reminders are refreshed when the app opens and when you leave it. Leaving the app is what schedules a "they're already hungry" nudge. Future warnings are scheduled even while you are still in the app, and they can fire after you lock the phone.

If you tap **Not now**, the card goes away. The Reminders button at the top can ask again. If you denied the system prompt, that button opens Settings so you can allow notifications for Pocket Pet.

### Try a reminder quickly

1. Run the app from Xcode so the debug menu is available (see below).
2. Allow reminders.
3. Tap the gear icon and tap **Send a test reminder**.
4. A banner arrives in about 5 seconds, even if the app is still open.
5. For a real hunger reminder: in the debug menu tap **Make them hungry**, then leave the app (swipe up to the home screen). A reminder arrives in about 2 minutes.

On the Simulator, reminders work too. If none arrive, open the Simulator's Settings app and check that notifications are allowed for Pocket Pet.

## Debug menu

The gear icon is only in debug builds, which is what you get when you press Run in Xcode. It will not be in an App Store build.

Use it to test days of pet life in a minute:

- **Forward 15 minutes / 1 hour / 6 hours / 1 day** moves the pet's clock. The widget uses the same clock, so they stay matched.
- **Skip to the next life stage** jumps to the hatch, or to the next age.
- **Fill fed, happy, and energy** restores them.
- **Make them hungry / sad / tired** drops one meter so you can see the face and the reminders.
- **Two minutes from flying home** puts a hatched alien close to the end. Then tap **Forward 15 minutes** and you should see them leave in the ship, with a letter and a new egg.
- **Use the real clock again** stops the fast-forward. The meters stay where they are; time just goes back to normal.
- **Send a test reminder** checks that notifications are allowed.

Fast-forward is saved with the pet, so it is still in effect if you quit and reopen. Use "Use the real clock again" when you are done testing.

## Change the bundle id

`com.example.petapp` is a placeholder. Before you run on a real iPhone, change it to an id that belongs to you. A bundle id looks like `com.yourname.pocketpet`. The widget's id must start with the app's id, so if the app is `com.yourname.pocketpet`, the widget is `com.yourname.pocketpet.widget`.

Change these, then run `xcodegen generate` again and reopen the project:

- `project.yml` — `PRODUCT_BUNDLE_IDENTIFIER` for PocketPet
- `project.yml` — `PRODUCT_BUNDLE_IDENTIFIER` for PocketPetWidget

The App Group is separate. It is the shared folder the app and the widget use. The placeholder is `group.com.example.petapp`. If you change it, use the same new value in all of these (a rebuild is enough; you don't have to regenerate unless you also changed `project.yml`):

- `PetCore/Sources/PetCore/PetIdentity.swift` — `appGroupID`
- `App/PocketPet.entitlements`
- `Widget/PocketPetWidget.entitlements`

The Free Device entitlements files are intentionally empty, so a free Apple ID can sign the app. Don't add the App Group there unless your team is allowed to use App Groups.

## Check the game rules

The rules (growth, decay, sleep, which adult form they become, flying home, and when reminders fire) live in the `PetCore` folder. That folder does not use SwiftUI or any iPhone-only framework, so the tests can run without a simulator.

On a Mac, with Xcode installed, open Terminal in this folder and run:

```bash
cd PetCore
swift test
```

You should see the tests pass. In Xcode, the **PocketPet** scheme also includes these tests: Product → Test, or Command-U.

## Project layout

- `PetCore` — the pet rules, the save file format, and the tests
- `Shared/Art` — the drawn pet. Replace these views when you have real art. The app asks them for a life stage and a mood.
- `Shared/StatMeterView.swift` — the three meters
- `App` — the iPhone screens, saving, and reminders
- `Widget` — the home screen widget
- `project.yml` — the description XcodeGen turns into `PocketPet.xcodeproj`

The pet is one JSON file named `pet-record.json`. With the normal scheme it lives in the App Group. With the free-device scheme it lives in the app's own storage.

## Later, for the App Store

A paid Apple Developer Program membership is only needed when you want TestFlight, the App Store, or the widget sharing data on a real phone. This project does not use private APIs, push notifications, iCloud, or a backend. Local reminders, the widget, and a privacy manifest are already in place. When you have a paid team, use the **PocketPet** scheme on your iPhone, keep the App Group entitlements, and register that App Group for both bundle ids in the Apple developer site (or let Xcode's automatic signing do it).
