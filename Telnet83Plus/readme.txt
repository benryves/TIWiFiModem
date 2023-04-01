-------------------------
Telnet 83 v1.6!  11/10/98
-------------------------
Justin Karneges
http://www.bigfoot.com/~infiniti99/telnet83.html
infiniti99@hotmail.com

Ti-83 Plus MirageOS port by Dan Englender
http://tcpa.calc.org
dan@calc.org
Any questions regarding the 83 Plus version should be sent to Dan.

Bug fixes in 1.6 release by Ben Ryves
https://benryves.com
benryves@benryves.com

*** Changes since v1.5 ***
- slowed down writing to the screen to prevent corrupt/scrambled display on
  newer calculator hardware with slower LCD drivers.
- fixed BEJOTY keys producing lowercase letters when in capital mode.
- fixed ctrl keys producing incorrect values and added ^@, ^\, ^^ and ^_.
- added overflow check to the receive buffer, large transfers are no longer
  truncated.
- clearing the screen now moves the cursor back to the top row.
- terminal and receive buffers are dynamically allocated, greatly reducing the
  size of the program.
- previous session state is stored in an external appvar named TELNET.
- pressing [WINDOW] enables an auto-scroll mode which will keep the cursor in
  view until the screen is scrolled manually with the arrow keys.
- the minimap can be set to only appear when the view is scrolled manually
  (shaded status icon) or also when the screen scrolls automatically (filled
  status icon).
- local echo can be toggled with [ON]+[Y=] or enabled/disabled with VT102
  escape sequences.
- character attributes are combined (e.g. setting inverse text then setting
  underlined text no longer clears the previous inverted text).
- more robust handling of arguments in escape sequences including default
  options or numbers with multiple digits.
- beep (BEL) now properly flashes the screen.
- reset back to initial state with [ON]+[CLEAR] or with VT100 ^[c.
- implemented more VT100 sequences, including:
  - IND (scroll up, ^[D) and RI (scroll down, ^[M).
  - NEL (new line, ^[E).
  - EL (^[[1K erases from start of line to cursor, ^[[2K erases whole line).
  - ED (^[[J or ^[[0J erases from start of screen to cursor, ^[[1J erases from
    cursor to end of screen).
  - DA (device attributes, ^[[c or ^[[0c) and DECID (identify terminal, ^[Z
    report VT100).
  - DSR (device status report, ^[[5n).
  - CPR (cursor position report, ^[[6n).
  - DECSC (save cursor, ^[7) and DECRC (restore cursor, ^[8).

*** Changes since v1.4 ***
- cleaned up the source, it's now part of this release.
- [GRAPH] now quits instead of [CLEAR].  [CLEAR] clears the screen now.
- graphics engine slightly sped up.
- Ctrl+DEL will send a real delete.  use in a situation where DEL shows ^H.

*** Changes since v1.0 ***
- removed interrupt driven link support and replaced with constant checking
  and a new routine.  thanks to Matthew Shepcar for the routine and David
  West for the idea.  telnet83 now operates at 9600bps! WOW!!
- added a minimap.  now you can see where you are in the 80x25 screen
  it will appear in the lower right anytime you scroll.  toggle it on or off
  with the [TRACE] button.
- added a easy line return button.  press [ZOOM] to return to the left border.
  now you don't have to waste time scrolling back to the left when reading
  web pages and such.
- more clean up.
- program is 2k larger now because it has a 2k recieve buffer.  i may change
  this in later versions, because it is a lot of memory.
- source code not included because it is not cleaned up

*** Changes since v.98 ***
- added tab and beep support (the beep is just an inverted screen)
- optimized the graphics engine.  now operates much faster
- cleaned up more of the code
- source now included

*** Changes since v.96 ***
- added interrupt driven linkport routines (instead of the old polling ones)
- added a few more vt100 sequences.  IRC works and LYNX is now actually
  usable.
- added input/output indicators in lower right corner
- cleaned up the code a LOT.  when I release the source with 1.0 it should
  actually be readable. =)
- renamed TELNET83.EXE to TELROUTE.EXE (still doesn't work with freeshells)
- renamed TERM (for the 83) to TELNET.

*** It is highly recommended that you print this document out.       ***
*** This way the key chart is easier to refer to.                    ***


-- Contents --
1) What is it?
2) How do I work it?
3) What it DOESN'T do yet
4) How to type all those keys from your keyboard on the dinky TI-83 keypad
5) *FAQ*
6) REDIRECT

-----------
What is it?
-----------
Telnet83 is a program that you can use to connect your TI-83+ graphing
calculator to the internet.  It's called "Telnet" because my intent for
the program was to dial up to a unix shell as if you were telnetting to
one.  Telnet83, however, is basically just a terminal program.  This means
you can use it for other purposes like connecting to BBS's.


-----------------
How do I work it?
-----------------
Run Telnet from MirageOS.  You will see author name and help information
when you first start up.

You can use the arrow keys on the TI-83+ to pan your view around.  Remember
that if the cursor goes off the edge of the screen that you may need to pan
the screen down to see what is coming in.  Whenever you pan the screen, a
minimap will appear in the lower right corner so that you know where you are
in relation to the entire 80x25 screen (you can only see 24x10 at a time).
Press the [GRAPH] key to quit the program.  For information on what the rest
of the keys do, refer the key chart later in this file.

Now, plug one end of a TI-Graphlink into the TI-83+ and the other end of it
into a null-modem cable.  Then, plug the null-modem cable into an external
modem.  Remember that you MUST have a null-modem cable.  Also, you may need
size/gender changers to make it plug into the modem properly.

Refer to your modem's user manual about how to operate the modem from a
terminal.  If the modem is connected to a wall jack or cellular phone, then
you can dial out.  You operate the modem the same exact way you would as if
you were using a PC terminal program.

Try typing AT and press enter (only if you are connected to a modem) and
see if the word OK appears.  If so, then you know you're in business.


----------------------
What it DOESN'T do yet
----------------------
There are a few VT100 commands that Telnet83 will ignore.  These are commands
that are either impossible to perform on the TI-83 OR are outdated sequences
that I haven't seen used in any unix program yet.


------------------------------------------------------------------------
How to type all those keys from your keyboard on the dinky TI-83+ keypad
------------------------------------------------------------------------
The controls for Telnet83 are:

Graph    = Quit
Clear    = Clears the screen
ON+Clear = clears and resets the console to initial state
Arrows   = Scroll
2nd      = numeric mode
Alpha    = capital mode
Mode     = Extra mode
X        = Ctrl mode
DEL      = BackSpace
STAT     = ESC
VARS     = TAB
ZOOM     = jump the viewport to the far left
WINDOW   = scroll the viewport to bring the cursor into view
TRACE    = toggle minimap mode
Y=       = Word Wrap toggle (useful when using irc -d)
ON+Y=    = local echo toggle

In order to fit all the keys onto the TI-83+ keypad, I split up the keypad
into 5 modes: Normal, Numeric, Capital, Extra, and Ctrl.  To go into these
modes, press the corresponding mode key above.  Press again to revert back
to Normal mode.  The Ctrl mode reverts back to Normal mode after pressing
any character in that mode.  The layouts are below.  The upperleft-most key
represents the MATH key and the lower-right-most key represents ENTER.

*** NORMAL ***          *** Numeric ***         *** Capital ***
+---+---+---+---+       +---+---+---+---+       +---+---+---+---+
| a | b | c |TAB|       |   |   |   |TAB|       | A | B | C |TAB|
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
| d | e | f | g | h |   |   |   |   |   | ^ |   | D | E | F | G | H |
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
| i | j | k | l | m |   |   | , | ( | ) | / |   | I | J | K | L | M |
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
| n | o | p | q | r |   |   | 7 | 8 | 9 | * |   | N | O | P | Q | R |
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
| s | t | u | v | w |   | < | 4 | 5 | 6 | - |   | S | T | U | V | W |
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
| x | y | z | @ | " |   | > | 1 | 2 | 3 | + |   | X | Y | Z | @ | ' |
+---+---+---+---+---+   +---+---+---+---+---+   +---+---+---+---+---+
    |SPC| . | / |RET|       | 0 | . | \ |RET|       |SPC| : | ? |RET|
    +---+---+---+---+       +---+---+---+---+       +---+---+---+---+

*** EXTRA ***           *** CTRL ***
+---+---+---+---+       +---+---+---+---+
|   |   |   |TAB|       |^A |^B |^C |^@ |
+---+---+---+---+---+   +---+---+---+---+---+
|   |   |   |   | _ |   |^D |^E |^F |^G |^H |
+---+---+---+---+---+   +---+---+---+---+---+
|   | ` | { | } | | |   |^I |^J |^K |^L |^M |
+---+---+---+---+---+   +---+---+---+---+---+
|   | & | * | ( | [ |   |^N |^O |^P |^Q |^R |
+---+---+---+---+---+   +---+---+---+---+---+
| < | $ | % | ^ | ] |   |^S |^T |^U |^V |^W |
+---+---+---+---+---+   +---+---+---+---+---+
| > | ! | @ | # | ~ |   |^X |^Y |^Z |^[ |^] |
+---+---+---+---+---+   +---+---+---+---+---+
    | ) | ; | ? | = |       |^\ |^^ |^_ |RET|
    +---+---+---+---+       +---+---+---+---+

*NOTE* - When in Extra mode, the arrow keys operate as VT100 arrows and
         will not scroll the screen.  If you want to scroll with the arrows,
         make sure that you aren't in Extra mode.  Use the VT100 arrows
         for applications like lynx.

         When in Ctrl mode, the [DEL] key acts as a real delete instead of
         ^H.  Use this if you get ^H when attempting to backspace.


-----
*FAQ*
-----
Q. How do I connect to the internet with it?
A. You must dial into a unix shell.  Most local Internet Service Providers
   offer such a thing.  Call your ISP and ask if they have a unix shell
   to dial into.  AOL, Prodigy, MSN, etc DO NOT offer one.

Q. Do I *have* to learn unix if I want to use the internet with the TI-83?
A. If you can think of another text-based method of using the internet,
   then use that.  Otherwise, YES you have to. =)

Q. How do I dial a number from Telnet83?
A. To dial, enter the command ATDTXXX-YYYY where XXX-YYYY is the number you
   want to dial.  Just type that in and press enter.  It usually takes about
   15-25 seconds to connect, so be patient.  When you finally connect, the
   modem should send a message to screen saying it connected.  You may need
   to scroll down.  ALWAYS REMEMBER TO SCROLL DOWN!

Q. What are AT commands?  What is a terminal program?
A. That is a big question to answer.  If you don't understand what a terminal
   program is, then you'll probably have a hard time using Telnet83.  You
   may want to try using PC terminal programs such as ProComm, Ripterm,
   Telix, COMit, Hyperterm, etc, since these programs come with extensive
   help files.  If you are able to dial up your ISP using one of those, then
   you might be able to tackle Telnet83.

Q. I don't have a cellular phone.  Are there any other ways to get wireless
   internet access?
A. Well... how else do you get wireless internet access?  Anyways, I did
   think of a few weird ideas: =)
   1) HAM radio and TNC (terminal node controller).  You will need to rig up
      your own host that has another HAM and TNC of it's own in order to
      relay the telnet session.  None of the software that comes with
      Telnet83 supports this, but if you are a programmer, this could
      certainly be done.  Hey, it's free airtime!
   2) Build your own transmitter.  FM, RF, whatever you like.
   3) Wireless modem.  I know they exist, but I don't know anything else
      about them.

Q. I don't have an external modem.  Can I still test out Telnet83 by
   connecting my TI-83+ to my computer and using my internal modem?
A. Yes.  I have provided a DOS program for utilizing an internal modem.
   The program is REDIRECT.EXE.  Its use is explained later in this file.

Q. Characters get garbled or dropped every once in awhile during use.  What
   up with that?
A. You are typing when data is coming in thru the linkport.  Unfortunately,
   the TI linkport can only send data one direction at a time.  There is
   no way around this except for TELNET83 to restrict typing during incoming
   data.  The reason that it doesn't do this is because if you were in a busy
   IRC channel, you would never be able to type anything because you would
   be constantly getting data.  To avoid getting garbled data, don't type
   until incoming data has stopped.  Also, type slowly.  Watch the indicator
   in the bottom right to see if data has stopped coming in.

Q. The infrequent bad characters (from the previous question) are messing
   up my IRC session!  Is there a way around this?
A. Well, I've gotten bad data during IRC and it is never harmful -- just a
   few extra characters appearing (from broken VT100 sequences).  You can
   run irc with the -d parameter to tell IRC to not use VT100.  It would also
   help to turn on the "wrap" option by pressing the [Y=] button.  You don't
   really have to worry about dropped characters in any other unix
   applications because, for the most part, irc is the only program that
   sends a lot of data to you while you type.

Q. How do I do E-mail, IRC, WWW, FTP, etc once connected?
A. Learn unix! =)

Q. What happened to TELROUTE that was in the previous versions?
A. Besides the fact that it didn't work on many systems, I got way too much
   feedback concerning TELROUTE.  Remember, the whole purpose of Telnet83
   is to NOT use it with a computer.  The only reason I included REDIRECT
   and TELROUTE in the first place was so that people without an external
   modem could see how Telnet83 operated by utilizing their computer's
   internal modem.  I discontinued including TELROUTE in this ZIP because
   it doesn't work that great.  Also, if you manage to scrounge up an old
   copy of TELROUTE, remember that it was designed for 300bps back when I
   wrote it, so you will not be able to see the full potential of Telnet83
   when using TELROUTE.

Q. I hooked it all up just like you said and I'm getting no response from
   the modem when I type on the keypad.
A. Verify that your modem actually works by plugging it into a PC and using
   a PC terminal program.  If you know for a fact that it should be working,
   then the problem is probably that you don't have a null-modem cable.
   Though it may seem like you don't need one if you were lucky enough to
   have a modem with a 25pin male connector, you still do.  The null-modem
   cable swaps the send/recv pins which is absolutely necessary.  If you're
   still having problems, email me.

Q. Right after I log into my ISP, I get a bunch of weird characters on the
   screen.  What is all that?  What's wrong?
A. The problem is that you are connecting to a PPP session.  Terminal
   programs do not understand PPP.  You will get the same problem if you use
   a PC program (like Hyperterm) and dial your ISP.  You must call up a
   unix shell.  Ask your ISP if they have a dial-up unix shell account for
   you.  In some cases, you may have to specify a parameter in your login
   name to decide whether you get PPP or a unix shell.  (like, for my ISP,
   the default is a unix shell.  if you want PPP, you have to login with a
   capital P in front of your name.  each ISP is different.  maybe you have
   to login as "username/UNIX" or "#username".)  in any event, call your ISP
   and see how you can do it.  It may turn out that they don't offer a dial-
   up shell account at all.  In that case, you're out of luck.

Q. I don't have a dial-up unix shell available thru my ISP.  What can I do?
A. You can set up your own dial-up shell with the Linux OS.  You will need
   two modems inside your computer for this.  One will be connected to your
   ISP and the other modem will be awaiting your call for the dial-up shell.
   This way, you can call *your* computer (instead of your ISP) and still
   get a dial-up shell.  You will be able to access the internet because your
   PC is online via another modem.  This method involves 3 modems (remember
   you need an external modem with your TI-83), so it's up to you if you
   think it's worth it.

--------
REDIRECT
--------
REDIRECT bridges two comports together.  This means that you can directly
manipulate an internal modem via the graphlink by bridging the graphlink
comport and the modem comport together.

REDIRECT is an MS-DOS program that has the following format:

redirect <modem comport> <irq> <graphlink comport> <irq>

so for example, typing this:
redirect 3 5 2 3

would make REDIRECT operate with a modem on COM3 with IRQ5 and a graphlink
on COM2 with IRQ3.  If you need to find out what your IRQ settings are,
go to your control panel and double click on the system icon.  Then, under
device manager, find the comport and choose properties.  The IRQ should be
under the resources tab.  Also, if your modem emulates a COM port (I know that
winmodems do) then redirect will not work... sorry.

Anyways, your calculator should now be connected to the modem.  Type AT
and press enter (on the TI83+) and the word OK should appear on the screen.
You may have to scroll down.  This is exactly the way it would be if you
were connected to an external modem.

*NOTE* Make sure your modem isn't in use, otherwise it won't work.  If you're
       connected to the internet with your computer then that counts as
       "in use" =).

----------------------------------------

If you have a comment or question about this program please email me!

-Justin Karneges [Infiniti]
infiniti99@hotmail.com
