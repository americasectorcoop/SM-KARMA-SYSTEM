DROP PROCEDURE IF EXISTS KS_BAN_ACTIVED;
DELIMITER $$
CREATE PROCEDURE KS_BAN_ACTIVED(IN _steam_id VARCHAR(32), IN _client_ip VARCHAR(16))
		NO SQL
BEGIN
	DECLARE done INT DEFAULT FALSE;

	-- Variables de transformación
	DECLARE _player_id BIGINT DEFAULT SteamIdTo64(_steam_id);
	DECLARE _player_ip BIGINT DEFAULT INET_ATON(_client_ip);


	DECLARE _ban_expiration INT DEFAULT NULL;
	DECLARE _ban_ip INT DEFAULT NULL;
	DECLARE _ban_player_id BIGINT DEFAULT NULL;

	DECLARE _is_banned TINYINT DEFAULT 0;
	DECLARE _message VARCHAR(255);


	DECLARE bans_actived CURSOR FOR (
		SELECT
			A.ip,
			A.steam_id,
			R.description,
			A.dt_ban_expiration
		FROM ks_bans_active AS A
		INNER JOIN ks_bans_reasons AS R ON R.id=A.ban_reason_id
		WHERE A.steam_id = _player_id OR A.ip = _player_ip
	);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
	
	OPEN bans_actived;
	
	START TRANSACTION;

		read_loop: LOOP

			FETCH bans_actived INTO _ban_ip, _ban_player_id, _message, _ban_expiration;

			IF _ban_expiration < NOW() THEN
				DELETE FROM ks_bans_active WHERE steam_id = _ban_player_id;
			ELSE

				IF _ban_player_id IS NOT NULL THEN 
					SELECT 1 INTO _is_banned;
					IF _ban_player_id = _player_id THEN
						SELECT 1 INTO done;
					ELSE
						SELECT "your ip is banned" INTO _message;
						SELECT 1 INTO done;
					END IF;
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