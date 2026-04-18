package com.drivelink.basemap;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.Profile;
import com.onthegomap.planetiler.reader.SourceFeature;

/**
 * Minimal basemap schema for DriveLink.
 *
 * Layers produced:
 *   water      — natural=water + Natural Earth ocean/lakes (polygon)
 *   landuse    — landuse / leisure (polygon)
 *   buildings  — building=* (polygon)
 *   roads      — highway=* (line, with kind + name)
 *   boundaries — admin boundaries (line, country/state)
 *   places     — populated places (point, kind + name)
 *
 * Deliberately omits:
 *   earth layer — style uses a flat background colour instead
 *   coastline polygons — we rely on Natural Earth's built-in ocean layer
 *
 * Attribute convention: every vector feature exposes a "kind" string
 * that style.json can filter on.
 */
public class DriveLinkProfile implements Profile {

  public static final String OSM_SOURCE = "osm";
  public static final String NE_SOURCE = "natural_earth";

  @Override
  public String name() {
    return "DriveLink Basemap";
  }

  @Override
  public String description() {
    return "Minimal OSM + Natural Earth basemap for offline Turkey routing.";
  }

  @Override
  public String attribution() {
    return "<a href=\"https://openstreetmap.org\">© OpenStreetMap</a> · Natural Earth";
  }

  @Override
  public void processFeature(SourceFeature source, FeatureCollector features) {
    String src = source.getSource();
    if (OSM_SOURCE.equals(src)) {
      processOsm(source, features);
    } else if (NE_SOURCE.equals(src)) {
      processNaturalEarth(source, features);
    }
  }

  // ── OSM ────────────────────────────────────────────────────────────

  private void processOsm(SourceFeature source, FeatureCollector features) {
    // Water features (lakes, rivers, reservoirs).
    if (source.canBePolygon()
        && (source.hasTag("natural", "water")
            || source.hasTag("water")
            || source.hasTag("waterway", "riverbank", "canal", "dock"))) {
      String kind = stringTag(source, "natural", "water");
      features.polygon("water")
          .setBufferPixels(4)
          .setMinZoom(7)
          .setAttr("kind", kind);
      return;
    }

    // Buildings — only at high zoom.
    if (source.canBePolygon() && source.hasTag("building")) {
      features.polygon("buildings")
          .setBufferPixels(2)
          .setMinZoom(13);
      return;
    }

    // Land use / leisure (parks, forests, residential, …).
    if (source.canBePolygon()
        && (source.hasTag("landuse") || source.hasTag("leisure", "park", "garden")
            || source.hasTag("natural", "wood", "grassland", "heath"))) {
      String kind = source.hasTag("landuse")
          ? source.getTag("landuse").toString()
          : (source.hasTag("leisure") ? source.getTag("leisure").toString()
              : source.getTag("natural").toString());
      features.polygon("landuse")
          .setBufferPixels(2)
          .setMinZoom(8)
          .setAttr("kind", kind);
      return;
    }

    // Roads — the biggest layer; zoom gating by importance.
    if (source.canBeLine() && source.hasTag("highway")) {
      String kind = source.getTag("highway").toString();
      int minZoom = highwayMinZoom(kind);
      var line = features.line("roads")
          .setBufferPixels(4)
          .setMinZoom(minZoom)
          .setAttr("kind", kind);
      if (source.hasTag("name")) {
        line.setAttr("name", source.getTag("name").toString());
      }
      if (source.hasTag("ref")) {
        line.setAttr("ref", source.getTag("ref").toString());
      }
      return;
    }

    // Administrative boundaries (country + state lines).
    if (source.canBeLine() && source.hasTag("boundary", "administrative")) {
      int adminLevel = intTag(source, "admin_level", 10);
      if (adminLevel <= 4) {
        String kind = adminLevel <= 2 ? "country" : "state";
        features.line("boundaries")
            .setBufferPixels(1)
            .setMinZoom(adminLevel <= 2 ? 2 : 4)
            .setAttr("kind", kind)
            .setAttr("admin_level", adminLevel);
      }
      return;
    }

    // Places (populated settlements).
    if (source.isPoint() && source.hasTag("place") && source.hasTag("name")) {
      String kind = source.getTag("place").toString();
      int minZoom = placeMinZoom(kind);
      if (minZoom >= 0) {
        features.point("places")
            .setBufferPixels(64)
            .setMinZoom(minZoom)
            .setAttr("kind", kind)
            .setAttr("name", source.getTag("name").toString())
            .setSortKey(-population(source));
      }
    }
  }

  // ── Natural Earth ──────────────────────────────────────────────────

  private void processNaturalEarth(SourceFeature source, FeatureCollector features) {
    String layer = source.getSourceLayer();
    if (layer == null) return;

    // Low-zoom ocean fill (OSM doesn't model oceans as polygons).
    if (layer.endsWith("_ocean")) {
      features.polygon("water")
          .setBufferPixels(4)
          .setMinZoom(0)
          .setMaxZoom(6)
          .setAttr("kind", "ocean");
      return;
    }

    // Low-zoom lakes for Turkey's big interior water bodies
    // (Van Gölü, Tuz Gölü, reservoirs).
    if (layer.endsWith("_lakes")) {
      features.polygon("water")
          .setBufferPixels(4)
          .setMinZoom(0)
          .setMaxZoom(7)
          .setAttr("kind", "lake");
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  private static int highwayMinZoom(String kind) {
    return switch (kind) {
      case "motorway", "motorway_link", "trunk", "trunk_link" -> 5;
      case "primary", "primary_link" -> 8;
      case "secondary", "secondary_link" -> 10;
      case "tertiary", "tertiary_link" -> 11;
      case "residential", "unclassified", "living_street" -> 13;
      case "service", "track" -> 14;
      default -> 14;
    };
  }

  private static int placeMinZoom(String kind) {
    return switch (kind) {
      case "country" -> 2;
      case "state", "region" -> 3;
      case "city" -> 5;
      case "town" -> 8;
      case "village" -> 11;
      case "hamlet", "suburb", "neighbourhood" -> 12;
      default -> -1;
    };
  }

  private static String stringTag(SourceFeature s, String key, String fallback) {
    Object v = s.getTag(key);
    return v == null ? fallback : v.toString();
  }

  private static int intTag(SourceFeature s, String key, int fallback) {
    Object v = s.getTag(key);
    if (v == null) return fallback;
    try {
      return Integer.parseInt(v.toString());
    } catch (NumberFormatException e) {
      return fallback;
    }
  }

  private static int population(SourceFeature s) {
    Object v = s.getTag("population");
    if (v == null) return 0;
    try {
      return Integer.parseInt(v.toString().replaceAll("[^0-9]", ""));
    } catch (NumberFormatException e) {
      return 0;
    }
  }
}
