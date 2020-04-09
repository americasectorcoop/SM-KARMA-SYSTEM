DROP PROCEDURE IF EXISTS KS_BAN_ACTIVED;
DELIMITER $$
CREATE PROCEDURE KS_BAN_ACTIVED(IN _steam_id VARCHAR(32), IN _client_ip VARCHAR(16))
		NO SQL
BEGIN
	DECLARE done INT DEFAULT FALSE;

	-- Variables de transformación
	DECLARE _player_id BIGINT DEFAULT SteamIdTo64(_steam_id);
	DECLARE _player_ip BIGINT DEFAULT INET_ATON(_client_ip);


	DECLARE _ban_ip INT DEFAULT NULL;
	DECLARE _ban_player_id BIGINT DEFAULT NULL;

	DECLARE _is_banned TINYINT DEFAULT 0;
	DECLARE _message VARCHAR(255);

	DECLARE bans_actived CURSOR FOR (
		SELECT
			L.target_ip,
			L.target_steam_id,
			R.description
		FROM ks_bans_logs AS L
		INNER JOIN ks_bans_reasons AS R ON R.id=L.ban_reason_id
		WHERE L.actived AND (L.target_steam_id = _player_id OR L.target_ip = _player_ip)
	);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	-- Descartando las ya expiradas activas
	UPDATE ks_bans_logs SET actived = 0 WHERE actived = 1 AND now() >= dt_ban_expiration AND target_steam_id=_player_id;
	
	OPEN bans_actived;
	
	START TRANSACTION;

		read_loop: LOOP

			FETCH bans_actived INTO _ban_ip, _ban_player_id, _message;

			IF _ban_player_id IS NOT NULL THEN 
				SELECT 1 INTO _is_banned;
				IF _ban_player_id = _player_id THEN
					SELECT 1 INTO done;
				ELSE
					SELECT "your ip is banned" INTO _message;
					SELECT 1 INTO done;
				END IF;
			END IF;

			IF done THEN
				LEAVE read_loop;
			END IF;

		END LOOP;

		SELECT _is_banned, _message;

	COMMIT;
	CLOSE bans_actived;

	
END$$
DELIMITER ;