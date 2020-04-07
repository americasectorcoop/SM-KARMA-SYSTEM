DROP PROCEDURE IF EXISTS KS_BAN_ADD;

DELIMITER $$
CREATE PROCEDURE KS_BAN_ADD(IN _steam_id VARCHAR(32), IN _reason_id INT UNSIGNED, IN _client_ip VARCHAR(16))
    NO SQL
BEGIN

	DECLARE _is_banned INT DEFAULT 0;
	DECLARE _time_to_ban INT DEFAULT 0;

	-- Variables de transformación
	DECLARE _player_id BIGINT DEFAULT SteamIdTo64(_steam_id);
	DECLARE _player_ip BIGINT DEFAULT INET_ATON(_client_ip);

	SELECT
		-- COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1 >= ban counter, numero de bans
		-- Se verifica si el conteo no supero el maximo permitodo
		-- si si se multiplica numer o de intento * tiempo por intento 
		IF((COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1) < R.max_limit, (COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1) * R.time_by_attempt, 0) INTO _time_to_ban
	FROM ks_bans_reasons AS R
	INNER JOIN ks_bans_logs AS L ON L.ban_reason_id=R.id AND L.forgiven=0
	WHERE
		L.steam_id = _player_id AND L.ban_reason_id = _reason_id
	GROUP BY L.steam_id;

	START TRANSACTION;

	INSERT INTO ks_bans_logs (steam_id, ban_reason_id, ip, dt_created) VALUES( _player_id, _reason_id, _player_ip, NOW() );

	INSERT INTO ks_bans_active (steam_id, ban_reason_id, ip, dt_ban_expiration) VALUES( _player_id, _reason_id, _player_ip,
		IF(_time_to_ban > 0, NOW() + INTERVAL _time_to_ban MINUTE, NULL)
	);

	COMMIT;

END$$
DELIMITER ;