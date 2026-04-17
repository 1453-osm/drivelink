/// Hierarchical region tree for offline map downloads.
/// Structure: Continent → Country → Region (optional)
///
/// Zoom ranges are conservative to keep download sizes small:
///   Country: 5-8 (road network visible, ~50-150 MB)
///   Region:  6-10 (city names + major roads, ~20-60 MB)
///   City:    8-13 (street level, ~15-40 MB)
/// Detail beyond these zooms is cached automatically when user browses.

class RegionNode {
  final String name;
  final List<RegionNode>? children;
  final double? north, south, east, west;
  final int? minZoom, maxZoom;
  final String? estimatedSize;

  const RegionNode({
    required this.name,
    this.children,
    this.north, this.south, this.east, this.west,
    this.minZoom, this.maxZoom,
    this.estimatedSize,
  });

  bool get isLeaf => children == null;
  bool get isDownloadable => north != null;
}

const regionTree = <RegionNode>[
  // ═══ AVRUPA ════════════════════════════════════════════════════════
  RegionNode(name: 'Avrupa', children: [
    RegionNode(name: 'Turkiye', children: [
      RegionNode(name: 'Turkiye (Tam)', north: 42.1, south: 35.8, east: 44.8, west: 25.7, minZoom: 5, maxZoom: 8, estimatedSize: '~80 MB'),
      RegionNode(name: 'Marmara Bolgesi', north: 42.11, south: 39.07, east: 31.02, west: 25.57, minZoom: 6, maxZoom: 11, estimatedSize: '~35 MB'),
      RegionNode(name: 'Ege Bolgesi', north: 39.88, south: 36.24, east: 31.74, west: 26.17, minZoom: 6, maxZoom: 11, estimatedSize: '~30 MB'),
      RegionNode(name: 'Akdeniz Bolgesi', north: 38.61, south: 35.81, east: 37.76, west: 29.20, minZoom: 6, maxZoom: 11, estimatedSize: '~30 MB'),
      RegionNode(name: 'Ic Anadolu Bolgesi', north: 41.10, south: 36.44, east: 38.78, west: 29.99, minZoom: 6, maxZoom: 11, estimatedSize: '~25 MB'),
      RegionNode(name: 'Karadeniz Bolgesi', north: 42.30, south: 39.84, east: 42.60, west: 30.57, minZoom: 6, maxZoom: 11, estimatedSize: '~25 MB'),
      RegionNode(name: 'Dogu Anadolu Bolgesi', north: 41.61, south: 36.97, east: 44.82, west: 37.27, minZoom: 6, maxZoom: 11, estimatedSize: '~20 MB'),
      RegionNode(name: 'Guneydogu Anadolu Bolgesi', north: 38.72, south: 36.64, east: 43.50, west: 36.45, minZoom: 6, maxZoom: 11, estimatedSize: '~20 MB'),
      RegionNode(name: 'Istanbul', north: 41.35, south: 40.80, east: 29.45, west: 28.55, minZoom: 8, maxZoom: 13, estimatedSize: '~25 MB'),
      RegionNode(name: 'Ankara', north: 40.10, south: 39.72, east: 33.05, west: 32.50, minZoom: 8, maxZoom: 13, estimatedSize: '~15 MB'),
      RegionNode(name: 'Izmir', north: 38.55, south: 38.20, east: 27.30, west: 26.80, minZoom: 8, maxZoom: 13, estimatedSize: '~12 MB'),
      RegionNode(name: 'Antalya', north: 37.10, south: 36.70, east: 30.90, west: 30.40, minZoom: 8, maxZoom: 13, estimatedSize: '~10 MB'),
      RegionNode(name: 'Bursa', north: 40.30, south: 40.10, east: 29.20, west: 28.85, minZoom: 8, maxZoom: 13, estimatedSize: '~8 MB'),
    ]),
    RegionNode(name: 'Almanya', children: [
      RegionNode(name: 'Almanya (Tam)', north: 55.1, south: 47.2, east: 15.1, west: 5.9, minZoom: 5, maxZoom: 8, estimatedSize: '~100 MB'),
      RegionNode(name: 'Bayern', north: 50.6, south: 47.3, east: 13.9, west: 8.9, minZoom: 6, maxZoom: 11, estimatedSize: '~30 MB'),
      RegionNode(name: 'Nordrhein-Westfalen', north: 52.5, south: 50.3, east: 9.5, west: 5.9, minZoom: 6, maxZoom: 11, estimatedSize: '~25 MB'),
      RegionNode(name: 'Berlin', north: 52.68, south: 52.34, east: 13.76, west: 13.09, minZoom: 8, maxZoom: 13, estimatedSize: '~10 MB'),
    ]),
    RegionNode(name: 'Fransa', children: [
      RegionNode(name: 'Fransa (Tam)', north: 51.1, south: 41.3, east: 9.6, west: -5.2, minZoom: 5, maxZoom: 8, estimatedSize: '~120 MB'),
      RegionNode(name: 'Ile-de-France', north: 49.2, south: 48.1, east: 3.6, west: 1.4, minZoom: 6, maxZoom: 11, estimatedSize: '~20 MB'),
      RegionNode(name: 'Provence-Alpes', north: 44.9, south: 43.0, east: 7.7, west: 4.2, minZoom: 6, maxZoom: 11, estimatedSize: '~18 MB'),
    ]),
    RegionNode(name: 'Italya', children: [
      RegionNode(name: 'Italya (Tam)', north: 47.1, south: 36.6, east: 18.5, west: 6.6, minZoom: 5, maxZoom: 8, estimatedSize: '~90 MB'),
      RegionNode(name: 'Lombardia', north: 46.6, south: 44.8, east: 11.4, west: 8.5, minZoom: 6, maxZoom: 11, estimatedSize: '~20 MB'),
      RegionNode(name: 'Roma', north: 42.05, south: 41.65, east: 12.85, west: 12.25, minZoom: 8, maxZoom: 13, estimatedSize: '~10 MB'),
    ]),
    RegionNode(name: 'Ispanya', children: [
      RegionNode(name: 'Ispanya (Tam)', north: 43.8, south: 36.0, east: 3.4, west: -9.3, minZoom: 5, maxZoom: 8, estimatedSize: '~100 MB'),
      RegionNode(name: 'Catalonia', north: 42.9, south: 40.5, east: 3.4, west: 0.2, minZoom: 6, maxZoom: 11, estimatedSize: '~20 MB'),
    ]),
    RegionNode(name: 'Ingiltere', north: 58.7, south: 49.9, east: 1.8, west: -8.2, minZoom: 5, maxZoom: 8, estimatedSize: '~70 MB'),
    RegionNode(name: 'Hollanda', north: 53.5, south: 50.7, east: 7.2, west: 3.4, minZoom: 6, maxZoom: 10, estimatedSize: '~20 MB'),
    RegionNode(name: 'Belcika', north: 51.5, south: 49.5, east: 6.4, west: 2.5, minZoom: 6, maxZoom: 10, estimatedSize: '~15 MB'),
    RegionNode(name: 'Avusturya', north: 49.0, south: 46.4, east: 17.2, west: 9.5, minZoom: 6, maxZoom: 10, estimatedSize: '~25 MB'),
    RegionNode(name: 'Isvicre', north: 47.8, south: 45.8, east: 10.5, west: 5.9, minZoom: 6, maxZoom: 10, estimatedSize: '~18 MB'),
    RegionNode(name: 'Yunanistan', north: 41.8, south: 34.8, east: 29.7, west: 19.3, minZoom: 5, maxZoom: 8, estimatedSize: '~50 MB'),
    RegionNode(name: 'Bulgaristan', north: 44.2, south: 41.2, east: 28.6, west: 22.4, minZoom: 6, maxZoom: 10, estimatedSize: '~20 MB'),
    RegionNode(name: 'Romanya', north: 48.3, south: 43.6, east: 29.7, west: 20.3, minZoom: 5, maxZoom: 8, estimatedSize: '~40 MB'),
    RegionNode(name: 'Polonya', north: 54.8, south: 49.0, east: 24.2, west: 14.1, minZoom: 5, maxZoom: 8, estimatedSize: '~60 MB'),
    RegionNode(name: 'Macaristan', north: 48.6, south: 45.7, east: 22.9, west: 16.1, minZoom: 6, maxZoom: 10, estimatedSize: '~25 MB'),
    RegionNode(name: 'Sirbistan', north: 46.2, south: 42.2, east: 23.0, west: 18.8, minZoom: 6, maxZoom: 10, estimatedSize: '~18 MB'),
    RegionNode(name: 'Hirvatistan', north: 46.6, south: 42.4, east: 19.4, west: 13.5, minZoom: 6, maxZoom: 10, estimatedSize: '~20 MB'),
    RegionNode(name: 'Portekiz', north: 42.2, south: 36.9, east: -6.2, west: -9.5, minZoom: 6, maxZoom: 10, estimatedSize: '~22 MB'),
  ]),

  // ═══ ASYA ══════════════════════════════════════════════════════════
  RegionNode(name: 'Asya', children: [
    RegionNode(name: 'Gurcistan', north: 43.6, south: 41.0, east: 46.7, west: 40.0, minZoom: 6, maxZoom: 10, estimatedSize: '~18 MB'),
    RegionNode(name: 'Azerbaycan', north: 41.9, south: 38.4, east: 50.4, west: 44.8, minZoom: 6, maxZoom: 10, estimatedSize: '~20 MB'),
    RegionNode(name: 'Ermenistan', north: 41.3, south: 38.8, east: 46.6, west: 43.4, minZoom: 6, maxZoom: 10, estimatedSize: '~12 MB'),
    RegionNode(name: 'Iran', north: 39.8, south: 25.1, east: 63.3, west: 44.0, minZoom: 5, maxZoom: 8, estimatedSize: '~90 MB'),
    RegionNode(name: 'Irak', north: 37.4, south: 29.1, east: 48.6, west: 38.8, minZoom: 5, maxZoom: 8, estimatedSize: '~35 MB'),
    RegionNode(name: 'Suriye', north: 37.3, south: 32.3, east: 42.4, west: 35.7, minZoom: 6, maxZoom: 9, estimatedSize: '~20 MB'),
    RegionNode(name: 'Lubnan', north: 34.7, south: 33.1, east: 36.6, west: 35.1, minZoom: 7, maxZoom: 11, estimatedSize: '~8 MB'),
    RegionNode(name: 'Urdun', north: 33.4, south: 29.2, east: 39.3, west: 34.9, minZoom: 6, maxZoom: 10, estimatedSize: '~15 MB'),
    RegionNode(name: 'Suudi Arabistan', north: 32.2, south: 16.4, east: 55.7, west: 34.5, minZoom: 5, maxZoom: 8, estimatedSize: '~70 MB'),
    RegionNode(name: 'BAE', north: 26.1, south: 22.6, east: 56.4, west: 51.6, minZoom: 6, maxZoom: 11, estimatedSize: '~15 MB'),
    RegionNode(name: 'Katar', north: 26.2, south: 24.5, east: 51.7, west: 50.7, minZoom: 7, maxZoom: 12, estimatedSize: '~5 MB'),
    RegionNode(name: 'Japonya', north: 45.5, south: 24.0, east: 146.0, west: 122.9, minZoom: 5, maxZoom: 8, estimatedSize: '~100 MB'),
    RegionNode(name: 'Guney Kore', north: 38.6, south: 33.1, east: 131.9, west: 124.6, minZoom: 6, maxZoom: 10, estimatedSize: '~25 MB'),
    RegionNode(name: 'Hindistan', north: 35.5, south: 6.7, east: 97.4, west: 68.1, minZoom: 4, maxZoom: 7, estimatedSize: '~80 MB'),
    RegionNode(name: 'Tayland', north: 20.5, south: 5.6, east: 105.6, west: 97.3, minZoom: 5, maxZoom: 8, estimatedSize: '~40 MB'),
    RegionNode(name: 'Ozbekistan', north: 45.6, south: 37.2, east: 73.1, west: 56.0, minZoom: 5, maxZoom: 8, estimatedSize: '~30 MB'),
    RegionNode(name: 'Kazakistan', north: 55.4, south: 40.6, east: 87.3, west: 46.5, minZoom: 4, maxZoom: 7, estimatedSize: '~50 MB'),
  ]),

  // ═══ AFRIKA ════════════════════════════════════════════════════════
  RegionNode(name: 'Afrika', children: [
    RegionNode(name: 'Misir', north: 31.7, south: 22.0, east: 37.0, west: 24.7, minZoom: 5, maxZoom: 8, estimatedSize: '~35 MB'),
    RegionNode(name: 'Fas', north: 35.9, south: 27.7, east: -1.0, west: -13.2, minZoom: 5, maxZoom: 8, estimatedSize: '~40 MB'),
    RegionNode(name: 'Tunus', north: 37.4, south: 30.2, east: 11.6, west: 7.5, minZoom: 6, maxZoom: 10, estimatedSize: '~18 MB'),
    RegionNode(name: 'Cezayir', north: 37.1, south: 18.9, east: 12.0, west: -8.7, minZoom: 4, maxZoom: 7, estimatedSize: '~50 MB'),
    RegionNode(name: 'Libya', north: 33.2, south: 19.5, east: 25.2, west: 9.3, minZoom: 5, maxZoom: 7, estimatedSize: '~30 MB'),
    RegionNode(name: 'Guney Afrika', north: -22.1, south: -34.8, east: 32.9, west: 16.5, minZoom: 5, maxZoom: 8, estimatedSize: '~50 MB'),
  ]),

  // ═══ AMERIKA ═══════════════════════════════════════════════════════
  RegionNode(name: 'Amerika', children: [
    RegionNode(name: 'ABD', children: [
      RegionNode(name: 'ABD Dogu Yakasi', north: 47.0, south: 25.0, east: -66.9, west: -90.0, minZoom: 5, maxZoom: 8, estimatedSize: '~120 MB'),
      RegionNode(name: 'ABD Bati Yakasi', north: 49.0, south: 32.5, east: -104.0, west: -125.0, minZoom: 5, maxZoom: 8, estimatedSize: '~100 MB'),
      RegionNode(name: 'New York', north: 40.92, south: 40.49, east: -73.70, west: -74.26, minZoom: 8, maxZoom: 13, estimatedSize: '~20 MB'),
      RegionNode(name: 'Los Angeles', north: 34.34, south: 33.70, east: -118.15, west: -118.67, minZoom: 8, maxZoom: 13, estimatedSize: '~18 MB'),
    ]),
    RegionNode(name: 'Kanada (Guney)', north: 54.0, south: 42.0, east: -52.6, west: -141.0, minZoom: 4, maxZoom: 7, estimatedSize: '~80 MB'),
    RegionNode(name: 'Meksika', north: 32.7, south: 14.5, east: -86.7, west: -118.4, minZoom: 5, maxZoom: 8, estimatedSize: '~80 MB'),
    RegionNode(name: 'Brezilya', north: 5.3, south: -33.8, east: -34.8, west: -73.9, minZoom: 4, maxZoom: 7, estimatedSize: '~100 MB'),
    RegionNode(name: 'Arjantin', north: -21.8, south: -55.1, east: -53.6, west: -73.6, minZoom: 5, maxZoom: 8, estimatedSize: '~70 MB'),
  ]),

  // ═══ OKYANUSYA ═════════════════════════════════════════════════════
  RegionNode(name: 'Okyanusya', children: [
    RegionNode(name: 'Avustralya', north: -10.7, south: -43.6, east: 153.6, west: 113.2, minZoom: 4, maxZoom: 7, estimatedSize: '~80 MB'),
    RegionNode(name: 'Yeni Zelanda', north: -34.4, south: -47.3, east: 178.6, west: 166.4, minZoom: 5, maxZoom: 8, estimatedSize: '~30 MB'),
  ]),
];
