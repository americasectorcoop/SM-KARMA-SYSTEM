DROP FUNCTION IF EXISTS `Multiply`;

DELIMITER //
CREATE AGGREGATE FUNCTION IF NOT EXISTS Multiply(x INT) RETURNS INT
BEGIN
 DECLARE result INT DEFAULT null;
 DECLARE CONTINUE HANDLER FOR NOT FOUND
 RETURN result;
      LOOP
          FETCH GROUP NEXT ROW;
          IF result IS NOT NULL THEN
            SET result = result*x;
          ELSE 
            SET result = x;
          END IF;
      END LOOP;
END //
DELIMITER ;