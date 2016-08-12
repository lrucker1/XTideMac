/*  Settings  XTide global settings

    Copyright (C) 1998  David Flater.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef XTSettingsInt_h
#define XTSettingsInt_h

// "STL containers are not intended to be used as base classes (their
// destructors are deliberately non-virtual).  Deriving from a
// container is a common mistake made by novices."
// -- Standard Template Library,
// http://en.wikipedia.org/w/index.php?title=Standard_Template_Library&oldid=98705028
// (last visited January 13, 2007).


class libxtide::Settings: public libxtide::ConfigurablesMap {
public:
   
   // Default constructor initializes map to config.hh defaults.  This
   // is desirable even if you intend to call nullify() immediately.
   // An empty map tells you nothing about what settings are even
   // available.  A nulled-out map gives you all the metadata (just no
   // data).
   // We could use Settings.cc, but all we need is the ConfigurablesMap
   Settings();
   
protected:
   
};

#endif /* XTSettingsInt_h */
