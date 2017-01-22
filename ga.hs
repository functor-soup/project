import Control.Monad.Trans.State
import System.Random
import Control.Applicative hiding (Const,)

data Variable = X | Y deriving (Show, Enum)
data Operation = Mult | Div | Add | Sub deriving (Show, Enum)

data Expr = Value Variable 
        | Const Float
        | Op Operation Expr Expr deriving (Show)

-- taken from LYAH
data Crumb = LeftCrumb Operation Expr | RightCrumb Operation Expr deriving (Show)
type Zipper = (Expr,[Crumb])

goLeft :: Zipper -> Maybe Zipper
goLeft (Op x l r, bs) = Just (l, (LeftCrumb x r):bs)
goLeft (Value _, _) = Nothing
goLeft (Const _, _) = Nothing

goRight :: Zipper -> Maybe Zipper
goRight (Op x l r, bs) = Just (r, (RightCrumb x l):bs)
goRight (Value _, _) = Nothing
goRight (Const _, _) = Nothing

goTop :: Zipper -> Maybe Zipper
goTop (t, (LeftCrumb f r):bs) = Just (Op f t r, bs)
goTop (t, (RightCrumb f l):bs) = Just (Op f l t, bs )
goTop (_, []) = Nothing

modifySubTree :: Expr -> Zipper -> Zipper
modifySubTree a (_, bs) = (a, bs)  

upMost :: Zipper -> Maybe Expr
upMost (t, []) = Just t
upMost x = goTop x >>= upMost

-- LYAH 

constructRandomTree :: Int -> State StdGen Expr 
constructRandomTree 0 = do
                          gen <- get
                          let (pick, newGen) = randomR (0,1) gen :: (Int,StdGen)
                          if pick == 0 
                            then do
                               let (pick, newGen2) = randomR (0,1) newGen :: (Int,StdGen)
                               put newGen2
                               return $ Value (toEnum pick :: Variable)
                            else do
                               let (pick, newGen2) = randomR (0,9) newGen :: (Float,StdGen)
                               put newGen2
                               return $ Const pick
                          
constructRandomTree x = do
                           gen <- get
                           let (pick, newGen) = randomR (0,3) gen
                           put newGen 
                           let start = (toEnum pick :: Operation)
                           left <- constructRandomTree (x-1) 
                           right <- constructRandomTree (x-1)
                           return $ Op start left right
                            
-- have to make this shorter
eval :: Expr -> Float -> Float -> Float
eval (Const z) _ _ = z
eval (Value X) x _ = x
eval (Value Y) _ y = y
eval (Op Div left right) x y = (/) (eval left x y) (eval right x y)
eval (Op Sub left right) x y = (-) (eval left x y) (eval right x y)
eval (Op Mult left right) x y = (*) (eval left x y) (eval right x y)
eval (Op Add left right) x y = (+) (eval left x y) (eval right x y)


-- pick subree 
pickSubtree :: Zipper -> State StdGen (Maybe Zipper)
pickSubtree x = do
                  gen <- get
                  let (choose, gen1) = randomR (0,1) gen :: (Float,StdGen)
                  put gen1
                  if (choose > 0.60)
                    then return $ Just x
                    else do
                           let (pick, gen2) = randomR (0,1) gen :: (Int, StdGen)
                           put gen2
                           case ([goLeft, goRight]!!pick) x of Just t -> pickSubtree t 
                                                               Nothing -> return Nothing

-- gotta refactor this whole thing, look into monad transformers
mutateTreeZipper :: Zipper -> State StdGen (Maybe Zipper)
mutateTreeZipper x = do
                       gen <- get 
                       let (pick, newGen) = randomR (0.0,1.0) gen :: (Float, StdGen)
                       put newGen
                       -- should change this so that the probability is very less for 
                       -- upper levels
                       if (pick > 0.70)
                         then do
                               let newTree = evalState (constructRandomTree 2) newGen
                               return $ Just $ modifySubTree newTree x                   
                         else return Nothing


treetreeBangBang :: Maybe Zipper -> Maybe Zipper -> Maybe Zipper
treetreeBangBang (Just x) (Just (y,ys)) = Just $ modifySubTree y x
treetreeBangBang _ _ = Nothing


-- convert to point free once I understand the point free version of this
generateExprPopulation :: Int -> Int -> State StdGen [Expr]
generateExprPopulation size depth = mapM constructRandomTree $ replicate size depth
                              
generateExprZipper :: Int -> Int -> State StdGen [Zipper]
generateExprZipper size depth = map (\x -> (x,[])) <$> generateExprPopulation size depth 

myShittyConnector :: Maybe Zipper -> State StdGen (Maybe Zipper)
myShittyConnector (Just x) = mutateTreeZipper x
myShittyConnector _ = return Nothing

a = evalState ((generateExprZipper 300 4) 
                 >>= mapM pickSubtree  
                 >>= mapM myShittyConnector) (mkStdGen 34000088526)
