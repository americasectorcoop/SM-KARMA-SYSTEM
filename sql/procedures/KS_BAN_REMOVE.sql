DROP PROCEDURE IF EXISTS KS_BAN_REMOVE;

DELIMITER $$
CREATE PROCEDURE KS_BAN_REMOVE(IN _steam_admin_id VARCHAR(32), IN _ban_id INT UNSIGNED, IN _unban_reason_id INT UNSIGNED)
    NO SQL
BEGIN

	-- Variables de transformación
	DECLARE _admin_id BIGINT DEFAULT SteamIdTo64(_steam_admin_id);

	START TRANSACTION;
		UPDATE ks_bans_logs
		SET actived = 0, forgiven = 1, admin_savior_steam_id=_admin_id, dt_unban=now(), unban_reason_id=_unban_reason_id
		WHERE id=_ban_id;
	COMMIT;

END$$
DELIMITER ;