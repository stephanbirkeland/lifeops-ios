# LifeOps 3D Printed Sensor Cases

OpenSCAD designs for DIY sensor enclosures.

## Files

| File | Description | Approx Size |
|------|-------------|-------------|
| `multi-sensor-case.scad` | Full sensor (ESP32-C3 + BME280 + PIR + LiPo) | 35×75×18mm |
| `door-sensor-case.scad` | Door contact (ESP32-C3 + reed switch + CR2032) | 28×35×12mm |
| `button-case.scad` | Smart button (ESP32-C3 + tactile + CR2032) | 32mm dia × 16mm |

## Requirements

### Software
- [OpenSCAD](https://openscad.org/) - Free 3D CAD software
- Any slicer (PrusaSlicer, Cura, etc.)

### Printer Settings
- **Material**: PLA recommended (easy to print, sufficient strength)
- **Layer height**: 0.2mm
- **Infill**: 20-30%
- **Supports**: Not required for most prints
- **Wall thickness**: 2-3 perimeters

## Printing Instructions

### Multi-Sensor Case

1. Open `multi-sensor-case.scad` in OpenSCAD
2. Press F6 to render
3. Export as STL (File → Export → STL)
4. Import to slicer
5. Print bottom case and lid separately
6. **Orientation**: Flat side down for both pieces

**Print time**: ~2 hours total
**Filament**: ~15g PLA

### Door Sensor Case

1. Open `door-sensor-case.scad` in OpenSCAD
2. Render and export
3. Print case, lid, and magnet holder
4. **Orientation**: All pieces flat side down

**Print time**: ~45 minutes total
**Filament**: ~8g PLA

### Button Case

1. Open `button-case.scad` in OpenSCAD
2. Render and export
3. Print case, lid, and button cap
4. **Orientation**: Case upside down (dome up), lid flat, cap standing

**Print time**: ~1 hour total
**Filament**: ~10g PLA

## Customization

Edit the parameters at the top of each file:

```scad
// Dimensions (mm)
esp32_width = 22;    // Adjust if your board differs
esp32_length = 18;

wall_thickness = 1.5; // Increase for strength
tolerance = 0.3;      // Adjust for your printer
```

### Common Adjustments

| Parameter | Effect |
|-----------|--------|
| `wall_thickness` | Thicker = stronger, heavier |
| `tolerance` | Larger = looser fit |
| `corner_radius` | Larger = more rounded |
| `$fn` | Higher = smoother curves (slower render) |

## Assembly Tips

### Multi-Sensor

1. Solder components to ESP32-C3 first
2. Test firmware before enclosing
3. Insert battery last
4. Route USB cable through port
5. Snap lid on (clips should click)

### Door Sensor

1. Flash ESP32-C3 firmware via USB
2. Solder reed switch wires
3. Insert CR2032 (+ side up)
4. Test door detection
5. Mount with adhesive or screws
6. Place magnet holder on frame

### Button

1. Flash firmware
2. Solder button to ESP32-C3
3. Insert CR2032
4. Place button cap in hole
5. Test click action
6. Snap lid on

## Post-Processing

### Sanding
- Light sanding with 220-400 grit for smooth finish
- Focus on visible surfaces

### Painting (Optional)
- Prime with plastic primer
- Use acrylic paint
- Clear coat for durability

### Waterproofing (Bathroom)
- Apply thin layer of silicone around seams
- Use conformal coating on PCB

## Troubleshooting

### Lid doesn't fit
- Increase `tolerance` parameter
- Sand inner lip
- Check for warping (use brim)

### Snap clips break
- Print with higher infill
- Print slower
- Use PETG for flexibility

### PIR doesn't detect well
- Ensure dome lens is unobstructed
- Check dome material is IR-transparent
- Enlarge opening if needed

### Battery doesn't fit
- Verify CR2032/LiPo dimensions
- Increase cavity size slightly

## Future Improvements

- [ ] Add LED indicator cutout
- [ ] Create wall-mount bracket
- [ ] Design magnetic mount option
- [ ] Add cable strain relief

## License

These designs are released for personal use with the LifeOps project.
