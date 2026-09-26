# Synthèse des flux analysés (as-of 2026-09-26)

| Réseau | Fichier | agency | routes | stops | trips | stop_times | calendar | calendar_dates | shapes (pts / shape_id) | fare_attributes | fare_rules | frequencies | valid_from | valid_to | validité |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AFTU | gtfs_AFTU.zip | 1 | 73 | 2401 | 11077 | 677918 | 4 | 40 | 9498 / 144 | 10 | 1196602 | NON (absent) | 2022-01-01 | 2023-12-31 | HISTORICAL |
| DDD | gtfs_Dem_Dikk.zip | 1 | 53 | 1277 | 9529 | 314029 | 4 | 40 | 3500 / 102 | 6 | None | NON (absent) | 2022-01-01 | 2023-12-31 | HISTORICAL |
| BRT | gtfs_BRT.zip | 1 | 2 | 79 | 4036 | 58674 | 0 | 69 | 6785 / 35 | None | None | NON (absent) | 2024-10-24 | 2024-12-31 | HISTORICAL |
| TER | gtfs_TER.zip | 1 | 6 | 26 | 572 | 7332 | 12 | None | None / None | None | None | NON (absent) | 2025-08-18 | 2025-08-31 | HISTORICAL |

## AFTU
- agences : [{"agency_id": "AFTU", "agency_name": "Association de Financement des Professionnels du transport Urbain", "agency_url": "https://aftu-senegal.org/", "agency_timezone": "Africa/Dakar", "agency_phone": "00221 33 859 02 88", "agency_lang": "fr"}]
- services : {"FULL": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], "start_date": "20220101", "end_date": "20231231"}, "LAV": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday"], "start_date": "20220101", "end_date": "20231231"}, "SAMEDI": {"days": ["saturday"], "start_date": "20220101", "end_date": "20231231"}, "DIMANCHE": {"days": ["sunday"], "start_date": "20220101", "end_date": "20231231"}}
- numéros de ligne présents (73) : 1, 2, 3, 4, 5, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91
- fichiers absents : frequencies.txt, transfers.txt, feed_info.txt
- contrôle coordonnées : {"dans_emprise_dakar_(lat 12..17, lon -18..-16)": 2401, "hors_emprise": 0, "header_order": ["stop_id", "stop_name", "stop_desc", "stop_lon", "stop_lat", "zone_id", "stop_url", "location_type"]}
- note qualité : calendar_dates.txt: en-tête séparé par ';' ('service_id;date;exception_type') alors que les lignes de données utilisent ',' — non conforme GTFS, lu en mode tolérant
- note qualité : trips.txt: 738 trip(s) sans aucune ligne dans stop_times.txt (horaire absent) — AFTU_31=85, AFTU_38=71, AFTU_41=70, AFTU_46=73, AFTU_52=190, AFTU_53=89, AFTU_57=91, AFTU_69=69
- comparaison : {"passbi_vs_dakar_bus": {"MISMATCH": 54, "MISSING_IN_SOURCE": 18, "MISSING_IN_DAKAR_BUS": 19}, "passbi_vs_official": {"MATCH": 49, "UNKNOWN": 18, "MISMATCH": 23, "MISSING_IN_OFFICIAL_LIST": 1}, "official_vs_dakar_bus": {"MISMATCH": 54, "MISSING_IN_SOURCE": 18, "MISSING_IN_DAKAR_BUS": 18, "UNKNOWN": 1}}

## DDD
- agences : [{"agency_id": "DDD", "agency_name": "Dakar Dem Dikk", "agency_url": "https://demdikk.sn/dakar-et-banlieue/", "agency_timezone": "Africa/Dakar", "agency_phone": "", "agency_lang": "fr"}]
- services : {"FULL": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], "start_date": "20220101", "end_date": "20231231"}, "LAV": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday"], "start_date": "20220101", "end_date": "20231231"}, "SAMEDI": {"days": ["saturday"], "start_date": "20220101", "end_date": "20231231"}, "DIMANCHE": {"days": ["sunday"], "start_date": "20220101", "end_date": "20231231"}}
- numéros de ligne présents (53) : 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 18, 20, 23, 102, 103, 105, 111, 121, 208, 210, 213, 217, 218, 219, 220, 221, 223, 227, 228, 231, 232, 233, 234, 301, 305, 308, 311, 315, 319, 323, 401, 402, 403, 404, 405, 501, 502, 503, 504
- fichiers absents : fare_rules.txt, frequencies.txt, transfers.txt, feed_info.txt
- contrôle coordonnées : {"dans_emprise_dakar_(lat 12..17, lon -18..-16)": 1277, "hors_emprise": 0, "header_order": ["stop_id", "stop_name", "stop_desc", "stop_lon", "stop_lat", "zone_id", "stop_url", "location_type"]}
- note qualité : calendar_dates.txt: en-tête séparé par ';' ('service_id;date;exception_type') alors que les lignes de données utilisent ',' — non conforme GTFS, lu en mode tolérant
- note qualité : trips.txt: 333 trip(s) sans aucune ligne dans stop_times.txt (horaire absent) — DDD_217=4, DDD_311=41, DDD_323=288
- comparaison : {"passbi_vs_dakar_bus": {"MISMATCH": 10, "MISSING_IN_DAKAR_BUS": 43, "MISSING_IN_SOURCE": 2, "UNKNOWN": 14}, "passbi_vs_official": {"MATCH": 33, "UNKNOWN": 2, "MISSING_IN_SOURCE": 14, "MISSING_IN_OFFICIAL_LIST": 19, "MISMATCH": 1}, "official_vs_dakar_bus": {"MISMATCH": 10, "MISSING_IN_DAKAR_BUS": 38, "MISSING_IN_SOURCE": 2, "UNKNOWN": 19}}

## BRT
- agences : [{"agency_id": "BRT", "agency_name": "BRT", "agency_url": "", "agency_timezone": "Africa/Dakar"}]
- services : {"0_3": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 8, "dates_removed": 0}, "0_1": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 10, "dates_removed": 0}, "0_6": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 10, "dates_removed": 0}, "0_2": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 10, "dates_removed": 0}, "0_4": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 10, "dates_removed": 0}, "1_7": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 12, "dates_removed": 0}, "0_5": {"days": [], "start_date": "", "end_date": "", "defined_only_in_calendar_dates": true, "dates_added": 9, "dates_removed": 0}}
- numéros de ligne présents (2) : B1, B2
- fichiers absents : fare_attributes.txt, fare_rules.txt, frequencies.txt, feed_info.txt
- contrôle coordonnées : {"dans_emprise_dakar_(lat 12..17, lon -18..-16)": 79, "hors_emprise": 0, "header_order": ["stop_id", "stop_name", "stop_desc", "stop_lat", "stop_lon", "zone_id", "location_type", "parent_station", "wheelchair_boarding", "vehicle_type"]}

## TER
- agences : [{"agency_id": "82abd4ab-f3b1-4852-92bf-32d82ebc5826", "agency_name": "SETER", "agency_url": "https://www.seter.sn/", "agency_timezone": "UTC", "agency_phone": "", "agency_email": ""}]
- services : {"38f23463-d512-5c3f-6ed7-33132080f1e8": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday"], "start_date": "20250825", "end_date": "20250831"}, "fa54f07d-702e-e4cc-6400-6efff8c64d25": {"days": ["friday", "saturday"], "start_date": "20250825", "end_date": "20250831"}, "4cd85026-70ce-fee8-af22-6008c0215228": {"days": ["saturday"], "start_date": "20250825", "end_date": "20250831"}, "db5eb1cc-bd0f-b516-2ab4-b4cf1998f578": {"days": ["sunday"], "start_date": "20250825", "end_date": "20250831"}, "8a62eb4e-3a8e-7ba3-a39b-4df1c864209a": {"days": ["wednesday", "thursday", "friday", "saturday"], "start_date": "20250818", "end_date": "20250824"}, "ac8d71e0-9004-ff7f-e71d-251a8d28201f": {"days": ["wednesday", "thursday", "friday"], "start_date": "20250818", "end_date": "20250824"}, "cec3ed22-c370-134c-6a0c-ec3b6a3117e6": {"days": ["thursday", "friday", "saturday"], "start_date": "20250818", "end_date": "20250824"}, "4db2746d-049c-77fc-60e7-928aab2fc765": {"days": ["thursday", "friday"], "start_date": "20250818", "end_date": "20250824"}, "75be6f61-e1f2-c62b-c602-0ba9ba92a5eb": {"days": ["friday", "saturday"], "start_date": "20250818", "end_date": "20250824"}, "d8799802-fcc1-014a-94c9-a2270693cc9f": {"days": ["saturday"], "start_date": "20250818", "end_date": "20250824"}, "1ed51a8d-1fbd-4ba5-f69a-bb6798679894": {"days": ["sunday"], "start_date": "20250818", "end_date": "20250824"}, "68f0b070-0d73-aa17-88ce-ed18734f1fee": {"days": ["monday", "tuesday", "wednesday", "thursday", "friday"], "start_date": "20250825", "end_date": "20250831"}}
- numéros de ligne présents (6) : 10001, 13005, 14922, 20001, 20922, 23001
- fichiers absents : calendar_dates.txt, shapes.txt, fare_attributes.txt, fare_rules.txt, frequencies.txt, transfers.txt, feed_info.txt
- contrôle coordonnées : {"dans_emprise_dakar_(lat 12..17, lon -18..-16)": 26, "hors_emprise": 0, "header_order": ["stop_id", "stop_code", "stop_name", "stop_desc", "stop_lat", "stop_lon", "location_type", "parent_station", "stop_timezone", "platform_code"]}

