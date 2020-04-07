DROP PROCEDURE IF EXISTS KS_BAN_REMOVE;

DELIMITER $$
CREATE PROCEDURE KS_BAN_REMOVE(IN _steam_player_id VARCHAR(32), IN _steam_admin_id VARCHAR(32), IN _unban_reason_id INT UNSIGNED)
    NO SQL
BEGIN

	-- Variables de transformación
	DECLARE _player_id BIGINT DEFAULT SteamIdTo64(_steam_player_id);
	DECLARE _admin_id BIGINT DEFAULT SteamIdTo64(_steam_admin_id);
	DECLARE _log_id INT DEFAULT 0;

	SELECT MAX(id) INTO _log_id FROM ks_bans_logs WHERE steam_id = _player_id;

	IF _log_id > 0 THEN
		START TRANSACTION;
			UPDATE ks_bans_logs SET forgiven = 1 WHERE id = _log_id;
			DELETE FROM ks_bans_active WHERE steam_id = _player_id;
			INSERT INTO ks_unbans_logs (ban_log_id, unban_reason_id, steam_id, dt_created) VALUES( _log_id, _unban_reason_id, _admin_id, now() );
		COMMIT;
	END IF;

END$$
DELIMITER ;