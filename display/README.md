


## MCAD <-> ECAD Workflow

### Digit Legend Symbols

1. Open `3478A_display.FCStd` in FreeCAD
2. Activate the TechDraw workspace
3. Select the appropriate page in the "Shape Export Pages" group
4. In the TechDraw menu, select "Export Page as SVG"
5. Open the SVG in Inkscape and export as PNG at 6000 pixels square
6. Open the `hp3478-display` project in KiCAD
7. Open the Image Converter tool, load the PNG, and export to a symbol file
8. Open the Symbol Editor tool and select the `0Local` library
9. Import the generated symbol file, copy and paste its graphics elements
   into the target symbol, and delete the imported symbol
10. Delete the imported colon and comma segments
11. Position the imported segments over the old segments
12. Remove the old segments
13. Save the symbol and update all matching symbols in the schematic


### Digit Outline Footprint

1. Open `3478A_display.FCStd` in FreeCAD
2. Activate the TechDraw workspace
3. Select the appropriate page in the "Shape Export Pages" group
4. In the TechDraw menu, select "Export Page as SVG"
5. Open the SVG in Inkscape
6. Select all and ungroup once
7. Turn off the fill paint
8. Set the stroke paint to 0.006" solid black
9. Save the SVG from Inkscape
10. Open the `hp2478-display` project in KiCAD
11. Open the Footprint Editor tool and select `0Local:Digit_Outline`
12. Import the SVG with "File -> Import -> Graphics..."
13. Position the newly imported lines over the old lines
14. Remove the old lines
15. Save the footprint and update all matching footprints in the board

