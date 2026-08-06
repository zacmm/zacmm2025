-- Connect to MySQL and run:
USE mattermost_dev;

-- Drop the table and create the view
DROP TABLE IF EXISTS AttributeView;

CREATE OR REPLACE VIEW AttributeView AS
  SELECT
       pv.GroupID,
       pv.TargetID,
       pv.TargetType,
       JSON_OBJECTAGG(pf.Name, pv.Value) AS Attributes
  FROM PropertyValues pv
  LEFT JOIN PropertyFields pf ON pf.ID = pv.FieldID
  GROUP BY GroupID, TargetID, TargetType;
