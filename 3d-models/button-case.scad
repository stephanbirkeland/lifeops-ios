// LifeOps Smart Button Case
// For ESP32-C3 Super Mini + Tactile Button + CR2032 battery
// Compact bedside button with satisfying click

// Dimensions (mm)
esp32_width = 22;
esp32_length = 18;
esp32_height = 5;

cr2032_diameter = 20;
cr2032_height = 3.2;

button_size = 6;  // 6x6mm tactile button
button_height = 4.3;

// Case parameters
wall_thickness = 1.5;
corner_radius = 3;  // Rounder for comfortable feel
tolerance = 0.3;

// Round button design
case_diameter = max(esp32_width, cr2032_diameter) + wall_thickness * 2 + 4;
case_height = esp32_height + cr2032_height + wall_thickness * 2 + 3;

// Quality
$fn = 64;

echo("Button case diameter:", case_diameter, "mm, height:", case_height, "mm");

module button_case() {
    difference() {
        // Outer shell - rounded cylinder
        hull() {
            cylinder(d = case_diameter, h = case_height - corner_radius);
            translate([0, 0, case_height - corner_radius])
                resize([case_diameter, case_diameter, corner_radius * 2])
                    sphere(d = case_diameter);
        }

        // Inner cavity
        translate([0, 0, wall_thickness])
            cylinder(d = case_diameter - wall_thickness * 2, h = case_height);

        // Button hole (top)
        translate([0, 0, case_height - wall_thickness - 0.1])
            cylinder(d = 8, h = wall_thickness + 0.2);

        // USB port cutout (side)
        translate([0, -case_diameter/2 - 0.1, wall_thickness + cr2032_height + 2])
            rotate([-90, 0, 0])
                hull() {
                    translate([-4, 0, 0]) cylinder(d = 3, h = wall_thickness + 0.2);
                    translate([4, 0, 0]) cylinder(d = 3, h = wall_thickness + 0.2);
                }
    }

    // Internal structure
    // CR2032 holder
    translate([0, 0, wall_thickness]) {
        difference() {
            cylinder(d = cr2032_diameter + 3, h = cr2032_height + 1);
            cylinder(d = cr2032_diameter + tolerance, h = cr2032_height + 1.1);
        }

        // Retaining clips
        for (a = [0, 90, 180, 270]) {
            rotate([0, 0, a])
                translate([cr2032_diameter/2 - 0.5, -0.5, 0])
                    cube([1.5, 1, cr2032_height + 1.5]);
        }
    }

    // ESP32 platform
    translate([0, 0, wall_thickness + cr2032_height + 1]) {
        difference() {
            cylinder(d = esp32_width + 4, h = 1.5);
            // Wiring hole
            cylinder(d = 8, h = 1.6);
        }
    }

    // ESP32 holder posts
    translate([0, 0, wall_thickness + cr2032_height + 2.5]) {
        for (x = [-esp32_width/2 - 0.5, esp32_width/2 - 1.5]) {
            translate([x, -esp32_length/2, 0])
                cube([2, esp32_length, 2]);
        }
    }
}

module button_cap() {
    // Button cap that transfers press to tactile switch
    cap_height = 3;
    cap_diameter = 12;

    difference() {
        union() {
            // Visible cap (ergonomic dome)
            hull() {
                cylinder(d = cap_diameter, h = cap_height - 1.5);
                translate([0, 0, cap_height - 1.5])
                    resize([cap_diameter - 2, cap_diameter - 2, 3])
                        sphere(d = cap_diameter);
            }

            // Press stem
            translate([0, 0, -4])
                cylinder(d = 6, h = 4.1);
        }

        // Hollow for spring effect
        translate([0, 0, -3.9])
            cylinder(d = 3, h = 3);
    }
}

module button_lid() {
    lid_height = wall_thickness * 1.5;

    difference() {
        // Flat bottom
        cylinder(d = case_diameter, h = lid_height);

        // Inner lip recess
        translate([0, 0, lid_height - 0.8])
            cylinder(d = case_diameter - wall_thickness * 2 + tolerance * 2, h = 0.9);
    }

    // Inner lip
    translate([0, 0, lid_height - 0.1])
        difference() {
            cylinder(d = case_diameter - wall_thickness * 2 - tolerance * 2, h = 2);
            cylinder(d = case_diameter - wall_thickness * 4, h = 2.1);
        }
}

// Render parts
button_case();

// Button cap
translate([case_diameter + 10, 0, 0])
    button_cap();

// Lid
translate([0, -case_diameter - 10, 0])
    button_lid();
