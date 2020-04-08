DELIMITER $$
CREATE FUNCTION SteamIdTo64(_steam_id_convert VARCHAR(128)) RETURNS bigint(20) unsigned
    NO SQL
BEGIN

DECLARE _steam64id BIGINT DEFAULT 76561197960265728;
DECLARE _value BIGINT DEFAULT _steam_id_convert;

SELECT
(
  CASE
    WHEN _steam_id_convert LIKE 'STEAM_%' THEN _steam64id + CAST(
      SUBSTRING(_steam_id_convert, 9, 1) AS UNSIGNED
    ) + CAST(SUBSTRING(_steam_id_convert, 11) * 2 AS UNSIGNED)
    WHEN _steam_id_convert LIKE '[U:%]' THEN _steam64id + CAST(
      SUBSTRING(
        _steam_id_convert,
        6,
        CHAR_LENGTH(_steam_id_convert) - 6
      ) AS UNSIGNED
    )
  END
) INTO _value;


return _value;

END$$
DELIMITER ;