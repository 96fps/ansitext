/* ansitext - Stylish ANSI terminal support for D.
 * https://github.com/SyntaxColoring/ansitext
 * See ReadMe.md for an introduction and API reference.
 * 
 * Copyright (c) 2013 Max Marrone <SyntaxColoring@gmail.com>
 * 
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

module ansitext;
import std.array: join;
import std.conv: text;

private:

immutable csi = "\033["; // \033 is octal for the ESC character.
immutable sgrReset = "0";
immutable sgrEnd = "m";

// Converts RGB coordinates to an XTerm 256-color palette index.
ubyte rgbToXterm(const double red, const double green, const double blue)
pure nothrow @safe @nogc
in
{
	assert(red   >= 0.0 && red   <= 1.0, "RGB channels should be from 0 to 1.");
	assert(green >= 0.0 && green <= 1.0, "RGB channels should be from 0 to 1.");
	assert(blue  >= 0.0 && blue  <= 1.0, "RGB channels should be from 0 to 1.");
}
body
{
	// Convert from 0-1 to 0-5, rounding to the nearest integer.
	const uint integralRed   = cast(uint)(  red*5 + 0.5);
	const uint integralGreen = cast(uint)(green*5 + 0.5);
	const uint integralBlue  = cast(uint)( blue*5 + 0.5);
	
	return cast(ubyte)(16 + integralRed*36 + integralGreen*6 + integralBlue);
}

unittest
{
	assert(rgbToXterm(0.0, 0.0, 0.0) == 16);  // Black.
	assert(rgbToXterm(1.0, 1.0, 1.0) == 231); // White.
	
	assert(rgbToXterm(1.0, 0.0, 0.0) == 196); // Red.
	assert(rgbToXterm(0.0, 1.0, 0.0) == 46);  // Green.
	assert(rgbToXterm(0.0, 0.0, 1.0) == 21);  // Blue.
}

// Helper struct for preserving the separateness of arguments passed to
// formatters.  This is needed to properly handle nesting.
//
// For example, in red(green("A", "B"), "C"), the red formatter receives
// "A" and "B" in an FormattedString so that it can work with them
// separately instead of as a single argument "AB."
struct FormattedString
{
	string[] parts;
	
	string opCast(string)() const pure nothrow @safe
	{
		return (parts ~ "").join(csi ~ sgrReset ~ sgrEnd);
	}
	
	alias toString = opCast!string;
}

public:

// Generalized functor for all formatters.  Wraps an SGR code to support
// nesting semantics.
struct Formatter
{
	string sgrParameters;
	
	this(string sgrParameters) pure nothrow @safe @nogc
	{
		this.sgrParameters = sgrParameters;
	}
	
	FormattedString opCall(Types...)(Types incomingArguments)
	const pure nothrow @safe
	{
		string[] outgoingArguments;
		
		foreach (incomingArgument; incomingArguments)
		{
			// If this formatter has received a pack of arguments relayed from
			// a more deeply-nested one, it needs to apply the code to each of
			// those relayed arguments individually.
			static if (is(typeof(incomingArgument) == FormattedString))
			{	
				FormattedString incomingFormattedString = incomingArgument;
				foreach (string relayedArgument; incomingFormattedString.parts)
				{
					outgoingArguments ~= (csi ~ sgrParameters ~ sgrEnd ~ relayedArgument);
				}
			}
			
			// The argument didn't come from another formatter, which means
			// it was passed in directly by calling code.  Therefore, it
			// needs to be converted here to a string (if it isn't one already).
			else
			{
				// Using to!string emulates writeln's flexibility with the types
				// of its arguments.  Calling code doesn't have to cast anything
				// that it wants to output through a formatter.
				outgoingArguments ~= (csi ~ sgrParameters ~ sgrEnd ~ text(incomingArgument));
			}
		}
		
		// Pass the arguments on to the enclosing level of the nest.
		return FormattedString(outgoingArguments);
	}
	
	Formatter opBinary(string op: "+")(const Formatter other)
	const pure nothrow @safe
	{
		return Formatter(sgrParameters ~ ";" ~ other.sgrParameters);
	}
}

Formatter customColor(double r, double g, double b) pure nothrow @safe
{
	return Formatter("38;5;" ~ text(rgbToXterm(r, g, b)));
}

Formatter customColorBG(double r, double g, double b) pure nothrow @safe
{
	return Formatter("48;5;" ~ text(rgbToXterm(r, g, b)));
}

immutable
{	
	Formatter defaultColor   = "39";
	Formatter black          = "30";
	Formatter red            = "31";
	Formatter green          = "32";
	Formatter yellow         = "33";
	Formatter blue           = "34";
	Formatter magenta        = "35";
	Formatter cyan           = "36";
	Formatter white          = "37";
	
	Formatter defaultColorBG = "49";
	Formatter blackBG        = "40";
	Formatter redBG          = "41";
	Formatter greenBG        = "42";
	Formatter yellowBG       = "43";
	Formatter blueBG         = "44";
	Formatter magentaBG      = "45";
	Formatter cyanBG         = "46";
	Formatter whiteBG        = "47";
	
	Formatter bold           = "1";
	Formatter noBold         = "22";
	
	Formatter blink          = "5";
	Formatter noBlink        = "25";
	
	Formatter underline      = "4";
	Formatter noUnderline    = "24";
	
	Formatter noFormatting   = sgrReset;
}
