// LifeOps Door Sensor Case
// For ESP32-C3 Super Mini + Reed Switch + CR2032 battery
// Ultra-compact for door mounting

// Dimensions (mm)
esp32_width = 22;
esp32_length = 18;
esp32_height = 5;

cr2032_diameter = 20;
cr2032_height = 3.2;

reed_length = 14;
reed_diameter = 2.5;

magnet_diameter = 6;
magnet_height = 3;

// Case parameters
wall_thickness = 1.2;
corner_radius = 1.5;
tolerance = 0.3;

// Calculated dimensions - vertical orientation
case_width = esp32_width + wall_thickness * 2 + 2;
case_length = esp32_length + cr2032_diameter/2 + wall_thickness * 2 + 3;
case_height = max(esp32_height, cr2032_height) + wall_thickness * 2 + 2;

// Quality
$fn = 32;

echo("Door sensor case:", case_width, "x", case_length, "x", case_height, "mm");

module rounded_box(w, l, h, r) {
    hull() {
        for (x = [r, w - r]) {
            for (y = [r, l - r]) {
                translate([x, y, 0])
                    cylinder(h = h, r = r);
            }
        }
    }
}

module door_sensor_case() {
    difference() {
        // Outer shell
        rounded_box(case_width, case_length, case_height, corner_radius);

        // Main cavity for ESP32
        translate([wall_thickness, wall_thickness, wall_thickness])
            cube([
                esp32_width + tolerance * 2,
                esp32_length + tolerance * 2,
                case_height
            ]);

        // CR2032 holder cavity
        translate([case_width/2, case_length - wall_thickness - cr2032_diameter/2 - 1, wall_thickness])
            cylinder(d = cr2032_diameter + tolerance * 2, h = case_height);

        // Reed switch channel
        translate([case_width/2, -0.1, case_height/2])
            rotate([-90, 0, 0])
                cylinder(d = reed_diameter + tolerance * 2, h = case_length/2);

        // Reed switch exit hole
        translate([case_width/2, wall_thickness + 2, wall_thickness - 0.1])
            cylinder(d = reed_diameter + 2, h = wall_thickness + 0.2);

        // USB port cutout (for initial programming)
        translate([wall_thickness + esp32_width/2 - 5, -0.1, wall_thickness + 1])
            cube([10, wall_thickness + 0.2, 3.5]);

        // Mounting holes
        for (y = [5, case_length - 5]) {
            translate([case_width/2, y, -0.1])
                cylinder(d = 3, h = wall_thickness + 0.2);
        }
    }

    // CR2032 retaining clips
    translate([case_width/2, case_length - wall_thickness - cr2032_diameter/2 - 1, wall_thickness]) {
        for (a = [45, 135, 225, 315]) {
            rotate([0, 0, a])
                translate([cr2032_diameter/2 - 1, 0, 0])
                    cube([2, 1, cr2032_height + 0.5]);
        }
    }

    // ESP32 support rails
    translate([wall_thickness, wall_thickness, wall_thickness]) {
        cube([1.5, esp32_length, 2]);
        translate([esp32_width + tolerance * 2 - 1.5, 0, 0])
            cube([1.5, esp32_length, 2]);
    }
}

module door_sensor_lid() {
    lid_height = wall_thickness + 1;

    difference() {
        // Main lid
        rounded_box(case_width, case_length, lid_height, corner_radius);

        // Inner lip recess
        translate([wall_thickness + tolerance, wall_thickness + tolerance, lid_height - 0.5])
            cube([
                case_width - wall_thickness * 2 - tolerance * 2,
                case_length - wall_thickness * 2 - tolerance * 2,
                0.6
            ]);
    }

    // Inner lip
    translate([wall_thickness + tolerance * 2, wall_thickness + tolerance * 2, lid_height - 0.1])
        difference() {
            cube([
                case_width - wall_thickness * 2 - tolerance * 4,
                case_length - wall_thickness * 2 - tolerance * 4,
                1.5
            ]);
            translate([wall_thickness, wall_thickness, -0.1])
                cube([
                    case_width - wall_thickness * 4 - tolerance * 4,
                    case_length - wall_thickness * 4 - tolerance * 4,
                    1.7
                ]);
        }
}

module magnet_holder() {
    // Separate piece for door frame
    difference() {
        rounded_box(magnet_diameter + 4, magnet_diameter + 4, magnet_height + 2, 1);

        // Magnet cavity
        translate([(magnet_diameter + 4)/2, (magnet_diameter + 4)/2, 1.5])
            cylinder(d = magnet_diameter + tolerance, h = magnet_height + 1);

        // Mounting hole
        translate([(magnet_diameter + 4)/2, (magnet_diameter + 4)/2, -0.1])
            cylinder(d = 2.5, h = 2);
    }
}

// Render parts
door_sensor_case();

// Lid
translate([case_width + 5, 0, 0])
    door_sensor_lid();

// Magnet holder
translate([0, case_length + 5, 0])
    magnet_holder();
