// LifeOps Multi-Sensor Case
// For ESP32-C3 Super Mini + BME280 + AM312 PIR + LiPo battery
// Designed for minimal size and 3D printing

// Dimensions (mm)
esp32_width = 22;
esp32_length = 18;
esp32_height = 5;

bme280_width = 13;
bme280_length = 11;
bme280_height = 3;

pir_diameter = 10;
pir_height = 23;
pir_lens_diameter = 8;

battery_width = 30;
battery_length = 40;
battery_height = 5;

tp4056_width = 26;
tp4056_length = 17;
tp4056_height = 4;

// Case parameters
wall_thickness = 1.5;
corner_radius = 2;
tolerance = 0.3;

// Calculated case dimensions
case_internal_width = max(esp32_width, battery_width) + 2;
case_internal_length = esp32_length + battery_length + tp4056_length + 4;
case_internal_height = max(battery_height + esp32_height, pir_height - 10) + 2;

case_width = case_internal_width + 2 * wall_thickness;
case_length = case_internal_length + 2 * wall_thickness;
case_height = case_internal_height + 2 * wall_thickness;

// Quality
$fn = 32;

echo("Case dimensions:", case_width, "x", case_length, "x", case_height, "mm");

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

module case_bottom() {
    difference() {
        // Outer shell
        rounded_box(case_width, case_length, case_height - wall_thickness, corner_radius);

        // Inner cavity
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_box(
                case_internal_width,
                case_internal_length,
                case_internal_height + 1,
                corner_radius - wall_thickness/2
            );

        // PIR lens hole (top)
        translate([case_width / 2, wall_thickness + 10, case_height - wall_thickness - 0.1])
            cylinder(d = pir_lens_diameter + tolerance * 2, h = wall_thickness + 0.2);

        // BME280 ventilation holes (side)
        translate([wall_thickness + case_internal_width - 5, case_length - wall_thickness - 0.1, wall_thickness + 5])
            rotate([-90, 0, 0])
                for (i = [0:2]) {
                    translate([0, i * 3, 0])
                        cylinder(d = 2, h = wall_thickness + 0.2);
                }

        // USB port cutout
        translate([case_width / 2 - 5, -0.1, wall_thickness + battery_height + 1])
            cube([10, wall_thickness + 0.2, 4]);

        // Lid snap clips (indents)
        for (x = [wall_thickness + 5, case_width - wall_thickness - 5]) {
            translate([x - 1, wall_thickness / 2, case_height - wall_thickness - 3])
                cube([2, wall_thickness, 3.5]);
        }
    }

    // Internal component supports
    // ESP32 holder
    translate([wall_thickness + (case_internal_width - esp32_width) / 2 - tolerance,
               wall_thickness + 2,
               wall_thickness]) {
        // Rails
        cube([2, esp32_length + tolerance * 2, 3]);
        translate([esp32_width + tolerance * 2 + 2, 0, 0])
            cube([2, esp32_length + tolerance * 2, 3]);
    }

    // Battery holder walls
    translate([wall_thickness + 2,
               wall_thickness + esp32_length + 5,
               wall_thickness]) {
        cube([2, battery_length + 2, battery_height + 1]);
        translate([battery_width, 0, 0])
            cube([2, battery_length + 2, battery_height + 1]);
    }
}

module case_lid() {
    // Lid thickness
    lid_height = wall_thickness * 2;

    difference() {
        union() {
            // Main lid
            rounded_box(case_width, case_length, lid_height, corner_radius);

            // Inner lip
            translate([wall_thickness + tolerance, wall_thickness + tolerance, lid_height - 0.1])
                rounded_box(
                    case_internal_width - tolerance * 2,
                    case_internal_length - tolerance * 2,
                    2,
                    corner_radius - wall_thickness/2
                );

            // Snap clips
            for (x = [wall_thickness + 5, case_width - wall_thickness - 5]) {
                translate([x - 0.8, wall_thickness / 2, lid_height])
                    cube([1.6, wall_thickness - 0.2, 3]);
            }
        }

        // PIR dome opening
        translate([case_width / 2, wall_thickness + 10, -0.1])
            cylinder(d = pir_diameter + tolerance * 2, h = lid_height + 0.2);

        // Ventilation slots
        translate([case_width / 2 + 10, case_length / 2, -0.1])
            for (i = [-2:2]) {
                translate([0, i * 4, 0])
                    cube([8, 2, lid_height + 0.2], center = true);
            }
    }
}

// Render parts
// Bottom case
case_bottom();

// Lid (offset for printing)
translate([case_width + 10, 0, 0])
    case_lid();
