/-
This is modified version of Lean.Meta.Tactic.Simp.Rewrite

Copyright (c) 2020 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
import Lean.Meta.ACLt
import Lean.Meta.Match.MatchEqsExt
import Lean.Meta.AppBuilder
import Lean.Meta.SynthInstance
import Lean.Meta.Tactic.Simp.Types
import Lean.Meta.Tactic.LinearArith.Simp

import SciLean.Tactic.CustomSimp.SimpGuard

namespace SciLean.Meta.CustomSimp

open Lean Meta Simp

-- @[simp, simp_guard f (λ x => x)]
-- theorem foo (a : Nat) (b : Int) (f : Nat → Nat) : 0 = 0 := by rfl

-- #eval show Lean.Elab.Term.TermElabM Bool from do pure (hasCustomSimpGuard (← getEnv) ``foo)

def mkEqTrans (r₁ r₂ : Result) : MetaM Result := do
  match r₁.proof? with
  | none => return r₂
  | some p₁ => match r₂.proof? with
    | none    => return { r₂ with proof? := r₁.proof? }
    | some p₂ => return { r₂ with proof? := (← Meta.mkEqTrans p₁ p₂) }

def synthesizeArgs (thmId : Origin) (xs : Array Expr) (bis : Array BinderInfo) (discharge? : Expr → SimpM (Option Expr)) : SimpM Bool := do
  -- simp guard
  match thmId with
  | .decl thmName => do
    match simpGuardAttr.getParam? (← getEnv) thmName with
    | some guards => do
        let doApplyGuard ← guards.allM λ (nth, valFun, mvarNum) => do

          -- TODO: figure out how to decide if we should call mkFreshTypeMVar or mkFreshExprMVar 
          let mvars ← Array.mkArray mvarNum () |>.mapM (λ _ => do pure <| some <| ← mkFreshTypeMVar)

          -- apply local context for `nth` argument and apply fresh mvars if necessary
          let val ← mkAppOptM' valFun ((xs.map some)[0:nth].toArray.append mvars)
          if (← isDefEq xs[nth]! val) then
            pure true
          else 
            pure false

        if doApplyGuard then
            -- TODO: get argument name 
            trace[Meta.Tactic.simp.discharge] "{← ppOrigin thmId}, not applied because of simp guard"
            return false

    | none => pure ()
  | _ => pure ()

  for x in xs, bi in bis do
    let type ← inferType x
    if bi.isInstImplicit then
      unless (← synthesizeInstance x type) do
        return false
    else if (← instantiateMVars x).isMVar then
      if (← isProp type) then
        match (← discharge? type) with
        | some proof =>
          unless (← isDefEq x proof) do
            trace[Meta.Tactic.simp.discharge] "{← ppOrigin thmId}, failed to assign proof{indentExpr type}"
            return false
        | none =>
          trace[Meta.Tactic.simp.discharge] "{← ppOrigin thmId}, failed to discharge hypotheses{indentExpr type}"
          return false
      else if (← isClass? type).isSome then
        unless (← synthesizeInstance x type) do
          return false
  return true
where
  synthesizeInstance (x type : Expr) : SimpM Bool := do
    match (← trySynthInstance type) with
    | LOption.some val =>
      if (← withReducibleAndInstances <| isDefEq x val) then
        return true
      else
        trace[Meta.Tactic.simp.discharge] "{← ppOrigin thmId}, failed to assign instance{indentExpr type}\nsythesized value{indentExpr val}\nis not definitionally equal to{indentExpr x}"
        return false
    | _ =>
      trace[Meta.Tactic.simp.discharge] "{← ppOrigin thmId}, failed to synthesize instance{indentExpr type}"
      return false

private def tryTheoremCore (lhs : Expr) (xs : Array Expr) (bis : Array BinderInfo) (val : Expr) (type : Expr) (e : Expr) (thm : SimpTheorem) (numExtraArgs : Nat) (discharge? : Expr → SimpM (Option Expr)) : SimpM (Option Result) := do
  let rec go (e : Expr) : SimpM (Option Result) := do
    if (← isDefEq lhs e) then
      unless (← synthesizeArgs thm.origin xs bis discharge?) do
        return none
      let proof? ← if thm.rfl then
        pure none
      else
        let proof ← instantiateMVars (mkAppN val xs)
        if (← hasAssignableMVar proof) then
          trace[Meta.Tactic.simp.rewrite] "{← ppSimpTheorem thm}, has unassigned metavariables after unification"
          return none
        pure <| some proof
      let rhs := (← instantiateMVars type).appArg!
      if e == rhs then
        return none
      if thm.perm then
        if !(← Expr.acLt rhs e) then
          trace[Meta.Tactic.simp.rewrite] "{← ppSimpTheorem thm}, perm rejected {e} ==> {rhs}"
          return none
      trace[Meta.Tactic.simp.rewrite] "{← ppSimpTheorem thm}, {e} ==> {rhs}"
      recordSimpTheorem thm.origin
      return some { expr := rhs, proof? }
    else
      unless lhs.isMVar do
        -- We do not report unification failures when `lhs` is a metavariable
        -- Example: `x = ()`
        -- TODO: reconsider if we want thms such as `(x : Unit) → x = ()`
        trace[Meta.Tactic.simp.unify] "{← ppSimpTheorem thm}, failed to unify{indentExpr lhs}\nwith{indentExpr e}"
      return none
  /- Check whether we need something more sophisticated here.
     This simple approach was good enough for Mathlib 3 -/
  let mut extraArgs := #[]
  let mut e := e
  for _ in [:numExtraArgs] do
    extraArgs := extraArgs.push e.appArg!
    e := e.appFn!
  extraArgs := extraArgs.reverse
  match (← go e) with
  | none => return none
  | some { expr := eNew, proof? := none, .. } => return some { expr := mkAppN eNew extraArgs }
  | some { expr := eNew, proof? := some proof, .. } =>
    let mut proof := proof
    for extraArg in extraArgs do
      proof ← mkCongrFun proof extraArg
    return some { expr := mkAppN eNew extraArgs, proof? := some proof }

def tryTheoremWithExtraArgs? (e : Expr) (thm : SimpTheorem) (numExtraArgs : Nat) (discharge? : Expr → SimpM (Option Expr)) : SimpM (Option Result) :=
  withNewMCtxDepth do
    let val  ← thm.getValue
    let type ← inferType val
    let (xs, bis, type) ← forallMetaTelescopeReducing type
    let type ← whnf (← instantiateMVars type)
    let lhs := type.appFn!.appArg!
    tryTheoremCore lhs xs bis val type e thm numExtraArgs discharge?

def tryTheorem? (e : Expr) (thm : SimpTheorem) (discharge? : Expr → SimpM (Option Expr)) : SimpM (Option Result) := do
  withNewMCtxDepth do
    let val  ← thm.getValue
    let type ← inferType val
    let (xs, bis, type) ← forallMetaTelescopeReducing type
    let type ← whnf (← instantiateMVars type)
    let lhs := type.appFn!.appArg!
    match (← tryTheoremCore lhs xs bis val type e thm 0 discharge?) with
    | some result => return some result
    | none =>
      let lhsNumArgs := lhs.getAppNumArgs
      let eNumArgs   := e.getAppNumArgs
      if eNumArgs > lhsNumArgs then
        tryTheoremCore lhs xs bis val type e thm (eNumArgs - lhsNumArgs) discharge?
      else
        return none
/--
Remark: the parameter tag is used for creating trace messages. It is irrelevant otherwise.
-/
def rewrite? (e : Expr) (s : DiscrTree SimpTheorem) (erased : PHashSet Origin) (discharge? : Expr → SimpM (Option Expr)) (tag : String) (rflOnly : Bool) : SimpM (Option Result) := do
  let candidates ← s.getMatchWithExtra e
  if candidates.isEmpty then
    trace[Debug.Meta.Tactic.simp] "no theorems found for {tag}-rewriting {e}"
    return none
  else
    let candidates := candidates.insertionSort fun e₁ e₂ => e₁.1.priority > e₂.1.priority
    for (thm, numExtraArgs) in candidates do
      unless inErasedSet thm || (rflOnly && !thm.rfl) do
        if let some result ← tryTheoremWithExtraArgs? e thm numExtraArgs discharge? then
          trace[Debug.Meta.Tactic.simp] "rewrite result {e} => {result.expr}"
          return some result
    return none
where
  inErasedSet (thm : SimpTheorem) : Bool :=
    erased.contains thm.origin

@[inline] def andThen (s : Step) (f? : Expr → SimpM (Option Step)) : SimpM Step := do
  match s with
  | Step.done _  => return s
  | Step.visit r =>
    if let some s' ← f? r.expr then
      return s'.updateResult (← mkEqTrans r s'.result)
    else
      return s

def rewriteCtorEq? (e : Expr) : MetaM (Option Result) := withReducibleAndInstances do
  match e.eq? with
  | none => return none
  | some (_, lhs, rhs) =>
    let lhs ← whnf lhs
    let rhs ← whnf rhs
    let env ← getEnv
    match lhs.constructorApp? env, rhs.constructorApp? env with
    | some (c₁, _), some (c₂, _) =>
      if c₁.name != c₂.name then
        withLocalDeclD `h e fun h =>
          return some { expr := mkConst ``False, proof? := (← mkEqFalse' (← mkLambdaFVars #[h] (← mkNoConfusion (mkConst ``False) h))) }
      else
        return none
    | _, _ => return none

@[inline] def tryRewriteCtorEq? (e : Expr) : SimpM (Option Step) := do
  match (← rewriteCtorEq? e) with
  | some r => return Step.done r
  | none  => return none

def rewriteUsingDecide? (e : Expr) : MetaM (Option Result) := withReducibleAndInstances do
  if e.hasFVar || e.hasMVar || e.isConstOf ``True || e.isConstOf ``False then
    return none
  else
    try
      let d ← mkDecide e
      let r ← withDefault <| whnf d
      if r.isConstOf ``true then
        return some { expr := mkConst ``True, proof? := mkAppN (mkConst ``eq_true_of_decide) #[e, d.appArg!, (← mkEqRefl (mkConst ``true))] }
      else if r.isConstOf ``false then
        return some { expr := mkConst ``False, proof? := mkAppN (mkConst ``eq_false_of_decide) #[e, d.appArg!, (← mkEqRefl (mkConst ``false))] }
      else
        return none
    catch _ =>
      return none

@[inline] def tryRewriteUsingDecide? (e : Expr) : SimpM (Option Step) := do
  if (← read).config.decide then
    match (← rewriteUsingDecide? e) with
    | some r => return Step.done r
    | none => return none
  else
    return none

def simpArith? (e : Expr) : SimpM (Option Step) := do
  if !(← read).config.arith then return none
  let some (e', h) ← Linear.simp? e (← read).parent? | return none
  return Step.visit { expr := e', proof? := h }

def simpMatchCore? (app : MatcherApp) (e : Expr) (discharge? : Expr → SimpM (Option Expr)) : SimpM (Option Step) := do
  for matchEq in (← Match.getEquationsFor app.matcherName).eqnNames do
    -- Try lemma
    match (← withReducible <| CustomSimp.tryTheorem? e { origin := .decl matchEq, proof := mkConst matchEq, rfl := (← isRflTheorem matchEq) } discharge?) with
    | none   => pure ()
    | some r => return some (Simp.Step.done r)
  return none

def simpMatch? (discharge? : Expr → SimpM (Option Expr)) (e : Expr) : SimpM (Option Step) := do
  if (← read).config.iota then
    let some app ← matchMatcherApp? e | return none
    simpMatchCore? app e discharge?
  else
    return none

def rewritePre (e : Expr) (discharge? : Expr → SimpM (Option Expr)) (rflOnly := false) : SimpM Step := do
  for thms in (← read).simpTheorems do
    if let some r ← rewrite? e thms.pre thms.erased discharge? (tag := "pre") (rflOnly := rflOnly) then
      return Step.visit r
  return Step.visit { expr := e }

def rewritePost (e : Expr) (discharge? : Expr → SimpM (Option Expr)) (rflOnly := false) : SimpM Step := do
  for thms in (← read).simpTheorems do
    if let some r ← rewrite? e thms.post thms.erased discharge? (tag := "post") (rflOnly := rflOnly) then
      return Step.visit r
  return Step.visit { expr := e }

def preDefault (e : Expr) (discharge? : Expr → SimpM (Option Expr)) : SimpM Step := do
  let s ← rewritePre e discharge?
  andThen s tryRewriteUsingDecide?

def postDefault (e : Expr) (discharge? : Expr → SimpM (Option Expr)) : SimpM Step := do
  let s ← rewritePost e discharge?
  let s ← andThen s (simpMatch? discharge?)
  let s ← andThen s simpArith?
  let s ← andThen s tryRewriteUsingDecide?
  andThen s tryRewriteCtorEq?

end SciLean.Meta.CustomSimp
