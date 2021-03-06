class Administrator::ErrorLogController < AdminController
  
  access_control :DEFAULT => 'Administrator - Technical'
  
  def index

   @date=params[:date]
   @date ||= Date.today.to_s(:db)

   conditions="date(created_at)='#{@date}'" if @date != 'all'

   @errors=ErrorLog.paginate(:order=>'created_at desc',:page => params[:page],:conditions=>conditions)
   @errors_count=ErrorLog.count(:conditions=>conditions)
   
   @distinct_dates=ErrorLog.find(:all,:select=>'distinct(DATE_FORMAT(date(created_at),"%Y-%m-%d")) AS date',:limit=>20,:order=>'created_at DESC')
   
 end
 
 def show
   
   @error=ErrorLog.find(params[:id])
   
 end
 
end
