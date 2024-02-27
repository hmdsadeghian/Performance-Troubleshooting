Use Master
Go
If (select OBJECT_ID('USP_CheckColumnDataTypesLength')) is not null
Begin
	Drop Procedure USP_CheckColumnDataTypesLength
End
Go

Create Procedure USP_CheckColumnDataTypesLength @DatabaseName Sysname as
SET NOCOUNT ON;  
Begin
	Declare @SQLString nvarchar(max)='';
	Drop Table if exists #columnList;

	CREATE TABLE #ColumnList(
		[TABLE_SCHEMA] [nvarchar](128) NULL,
		[TABLE_NAME] [sysname] NOT NULL,
		[COLUMN_NAME] [sysname] NULL,
		[COLUMN_DEFAULT] [nvarchar](4000) NULL,
		[IS_NULLABLE] [varchar](3) NULL,
		[DATA_TYPE] [nvarchar](128) NULL,
		[ConcatedDataType] [nvarchar] (128) null,
		[CHARACTER_MAXIMUM_LENGTh] [int] NULL,
		[CHARACTER_OCTET_LENGTH] [int] NULL,
		[NUMERIC_PRECISION] [tinyint] NULL,
		[NUMERIC_SCALE] [int] NULL,
		[Max_Length] int null,
		[Data_length] int null
	);

	set @SQLString='
	Insert Into 
		#ColumnList
	select 
		ic.TABLE_SCHEMA,
		ic.TABLE_NAME,
		ic.COLUMN_NAME,
		ic.COLUMN_DEFAULT,
		ic.IS_NULLABLE,
		ic.DATA_TYPE,
		Case 
			when 
				ic.DATA_TYPE in (''nvarchar'',''varchar'',''char'',''nchar'',''varbinary'',''decimal'',''binary'',''datetime2'',''time''
					,''datetimeoffset'')
			Then	
				ic.data_type+''(''+coalesce(
											cast(case when ic.CHARACTER_MAXIMUM_LENGTh=-1 then ''max'' else  cast(ic.CHARACTER_MAXIMUM_LENGTh as nvarchar) end as nvarchar),
											cast(ic.numeric_precision as nvarchar)+'',''+cast(IC.numeric_Scale as nvarchar),
											cast(ic.datetime_precision as nvarchar)
										 )+'')''
		 Else ic.data_Type end as Data_type,

		ic.CHARACTER_MAXIMUM_LENGTh,
		ic.CHARACTER_OCTET_LENGTH,
		ic.NUMERIC_PRECISION,
		ic.NUMERIC_SCALE,
		0 as Max_Length,
		0 as Data_Length
	from 
		['+@DatabaseName+'].information_schema.Columns as IC
	Inner join 
		['+@DatabaseName+'].INFORMATION_SCHEMA.tables as IT 
	on 
		ic.TABLE_SCHEMA = it.TABLE_SCHEMA
	and ic.TABLE_NAME = it.TABLE_NAME 
	and it.TABLE_TYPE=''base table''
	Where 
		ic.DATA_TYPE not in (''xml'',''HierarchyId'',''UniqueIdentifier'',''geography'',''bit'');';
	
	Exec(@SQLString);
  
	DECLARE @Table_Name nvarchar(500),
		@Schema_Name NVarchar(500),@Column_Name nvarchar(500),
		@Max_Value int ,@ParmDefinition nvarchar(200), 
		@Data_Len int;
  
  
	DECLARE Count_cursor CURSOR forward_only FOR   
	SELECT distinct Table_Schema,
		   Table_Name
	FROM #ColumnList
	ORDER BY Table_Schema,Table_Name;  
	OPEN Count_cursor
  
	FETCH NEXT FROM Count_cursor
	INTO @Schema_Name,@Table_Name
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		PRINT ' '  
		set @max_Value=0;
		Set @SQLString = '
						 if (Select count(*) from ['+@DatabaseName+'].['+@Schema_Name+'].['+@Table_Name+'] with(nolock))=0 
						 Begin
							Delete From 
								#ColumnList
							Where 
								Table_Name=@TableName and Table_Schema=@SchemaName
						 End;'
		SET @ParmDefinition = N'@TableName nvarchar(500) , @SchemaName Nvarchar(500)'; 
		exec Sp_executeSQl @SqlString ,@ParmDefinition , @TableName = @Table_Name , @SchemaName = @Schema_Name ;
		FETCH NEXT FROM Count_cursor   
		INTO @Schema_Name,@Table_Name  
	END   
	CLOSE Count_cursor;  
	DEALLOCATE Count_cursor; 

  
	DECLARE Column_cursor CURSOR forward_only FOR   
	SELECT Table_Schema,
		   Table_Name,
		   column_Name
	FROM #ColumnList
	ORDER BY Table_Schema,Table_Name;  
	OPEN Column_cursor  
  
	FETCH NEXT FROM Column_cursor     
	INTO @Schema_Name,@Table_Name,@Column_Name  
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		PRINT ' '  
		Print 'Calculate Max length of '+@Schema_Name+'.'+@Table_Name+'.'+@Column_Name+';';
		set @max_Value=0;
		Set @SQLString = 'set @maxvalue=0;
							Select @MaxValue=max(len(['+@Column_Name+'])) , @DataLen = DATALENGTH(['+@Column_Name+'])'+
							  +' From ['+@DatabaseName+'].['+@Schema_Name+'].['+@Table_Name+'] with(nolock)
							  Group by ['+@Column_Name+'];'
		SET @ParmDefinition = N'@MaxValue int OUTPUT, @DataLen int output'; 
		exec Sp_executeSQl @SqlString ,@ParmDefinition , @Maxvalue = @Max_value output , @DataLen = @Data_Len output ;
		Update #ColumnList
		Set Max_Length = @Max_Value  , Data_length = @Data_Len
		where TABLE_NAME= @Table_Name and [Table_Schema] = @Schema_Name and [Column_Name]=@Column_Name;
		FETCH NEXT FROM Column_cursor   
		INTO @Schema_Name,@Table_Name,@Column_Name  
	END   
	CLOSE Column_cursor;  
	DEALLOCATE Column_cursor; 

	select 
		Table_Schema,
		Table_Name,
		Column_Name,
		ConcatedDataType,
		Max_Length 
	from #columnList
	Order by character_maximum_length desc, max_length desc
End
Go

