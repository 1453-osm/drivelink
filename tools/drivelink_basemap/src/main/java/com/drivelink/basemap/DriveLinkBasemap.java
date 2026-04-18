package com.drivelink.basemap;

import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.config.Arguments;
import java.nio.file.Path;

/**
 * Entry point — wires up the Planetiler runtime with our minimal profile
 * and two data sources (OSM PBF and Natural Earth).
 *
 * Usage:
 *   java -jar drivelink-basemap.jar \
 *       --osm_path=turkey-latest.osm.pbf \
 *       --output=turkey.pmtiles \
 *       --download --force
 *
 * Natural Earth is fetched automatically from naciscdn.org when needed.
 * No OSM coastline / Daylight landcover downloads are performed.
 */
public class DriveLinkBasemap {

  public static void main(String[] args) throws Exception {
    Arguments arguments = Arguments.fromArgsOrConfigFile(args);

    Path osmPath = arguments.file(
        "osm_path", "OSM input PBF", Path.of("data/sources/turkey-latest.osm.pbf"));
    Path output = arguments.file(
        "output", "Output PMTiles archive", Path.of("data/turkey.pmtiles"));
    Path nePath = arguments.file(
        "ne_path", "Natural Earth sqlite (auto-downloaded if missing)",
        Path.of("data/sources/natural_earth_vector.sqlite.zip"));

    Planetiler.create(arguments)
        .setProfile(new DriveLinkProfile())
        .addNaturalEarthSource(
            DriveLinkProfile.NE_SOURCE,
            nePath,
            "https://naciscdn.org/naturalearth/packages/natural_earth_vector.sqlite.zip")
        .addOsmSource(DriveLinkProfile.OSM_SOURCE, osmPath)
        .overwriteOutput(output)
        .run();
  }
}
