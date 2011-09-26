-module(test_case).
-compile(export_all).

-include("../include/BFExchangeService.hrl").

call_api() ->
    GX_Wsdl = detergent:initModel("./priv/BFExchangeService.wsdl"),
    
    GetAllMarketsReq = #'P:GetAllMarketsReq'{'header' = #'P:APIRequestHeader'{sessionToken = "any_string_to_test_parsing",
									      clientStamp = "0" }
					    },
    detergent:call(GX_Wsdl, "getAllMarkets", [GetAllMarketsReq]).
    
