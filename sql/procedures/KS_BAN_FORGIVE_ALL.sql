DROP PROCEDURE IF EXISTS KS_BAN_FORGIVE_ALL;

DELIMITER $$
CREATE PROCEDURE KS_BAN_FORGIVE_ALL(IN _steam_player_id VARCHAR(32), IN _steam_admin_id VARCHAR(32), IN _unban_reason_id INT UNSIGNED)
    NO SQL
BEGIN

  -- Variables de transformación
  DECLARE _player_id BIGINT DEFAULT SteamIdTo64(_steam_player_id);
  DECLARE _admin_id BIGINT DEFAULT SteamIdTo64(_steam_admin_id);

  -- Descartando las ya expiradas activas
  UPDATE ks_bans_logs SET actived = 0 WHERE actived = 1 AND now() >= dt_ban_expiration AND target_steam_id=_player_id;
  -- Las que aun no expiran se quedan como perdonadas
  UPDATE ks_bans_logs
  SET actived = 0, forgiven = 1, admin_savior_steam_id=_admin_id, dt_unban=now()
  WHERE actived = 1 AND target_steam_id=_player_id;

END$$
DELIMITER ;